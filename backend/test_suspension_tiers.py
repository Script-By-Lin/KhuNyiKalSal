"""
Unit test suite verifying progressive 3-tier escalating user suspension system:
- Tier 1: 1-Day Suspension (5 cancellations in 24h)
- Tier 2: 10-Days Suspension (2nd offense)
- Tier 3: 100-Years Ban (3rd offense)
- Auto-reactivation on expiration
- Admin manual unsuspend and suspend controls
- SOS creation blocking during suspension
"""

import os
import sys
import unittest
import uuid
from datetime import datetime, timezone, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from fastapi import HTTPException

from app.database import Base
from app.models import Account, RoleEnum, Emergency, EmergencyType, EmergencyStatus, UserProfile
from app.core.security import hash_password
from app.core.abuse import evaluate_cancellation_abuse, check_sos_limit
from app.api.admin import list_users, admin_unsuspend_user, admin_suspend_user, AdminSuspendUserRequest


class TestUserSuspensionTiers(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
        self.session_factory = async_sessionmaker(self.engine, class_=AsyncSession, expire_on_commit=False)

        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with self.session_factory() as db:
            self.user = Account(
                id=uuid.uuid4(),
                email="caller@test.com",
                hashed_password=hash_password("Pass1234"),
                role=RoleEnum.USER,
                is_active=True,
                is_suspended=False,
                suspension_count=0,
            )
            self.user_prof = UserProfile(
                account_id=self.user.id,
                full_name="Test Caller",
                phone_number="09111222333",
            )
            self.admin = Account(
                id=uuid.uuid4(),
                email="admin@test.com",
                hashed_password=hash_password("Pass1234"),
                role=RoleEnum.ADMIN,
                is_active=True,
            )
            db.add_all([self.user, self.user_prof, self.admin])
            await db.commit()

    async def asyncTearDown(self):
        await self.engine.dispose()

    async def test_tier1_one_day_suspension_on_five_cancellations(self):
        """Verify 5 cancellations in 24h triggers Tier 1 (1 day suspension)."""
        async with self.session_factory() as db:
            user = await db.get(Account, self.user.id)
            # Add 5 cancelled emergencies
            for _ in range(5):
                e = Emergency(
                    user_id=user.id,
                    type=EmergencyType.MEDICAL,
                    status=EmergencyStatus.CANCELLED,
                    location_lat=16.8661,
                    location_lng=96.1951,
                    created_at=datetime.now(timezone.utc) - timedelta(minutes=10),
                )
                db.add(e)
            await db.commit()

            result = await evaluate_cancellation_abuse(user, db)
            self.assertIsNotNone(result)
            self.assertTrue(result["is_suspended"])
            self.assertEqual(result["suspension_tier"], 1)
            self.assertTrue(user.is_currently_suspended)
            self.assertGreater(user.remaining_suspension_seconds, 86000)  # ~24h
            self.assertIn("1st Offense", user.suspension_reason)

    async def test_tier2_ten_days_suspension_on_second_offense(self):
        """Verify 2nd offense escalates to Tier 2 (10 days suspension)."""
        async with self.session_factory() as db:
            user = await db.get(Account, self.user.id)
            user.suspension_count = 1  # Previous tier 1 offense

            # Add 5 cancelled emergencies
            for _ in range(5):
                e = Emergency(
                    user_id=user.id,
                    type=EmergencyType.ACCIDENT,
                    status=EmergencyStatus.CANCELLED,
                    location_lat=16.8661,
                    location_lng=96.1951,
                    created_at=datetime.now(timezone.utc) - timedelta(minutes=5),
                )
                db.add(e)
            await db.commit()

            result = await evaluate_cancellation_abuse(user, db)
            self.assertIsNotNone(result)
            self.assertEqual(result["suspension_tier"], 2)
            self.assertEqual(user.suspension_count, 2)
            self.assertGreater(user.remaining_suspension_seconds, 86400 * 9)  # ~10 days
            self.assertIn("2nd Offense", user.suspension_reason)

    async def test_tier3_one_hundred_years_permanent_ban_on_third_offense(self):
        """Verify 3rd offense escalates to Tier 3 (100 years permanent ban)."""
        async with self.session_factory() as db:
            user = await db.get(Account, self.user.id)
            user.suspension_count = 2  # Previous tier 2 offense

            for _ in range(5):
                e = Emergency(
                    user_id=user.id,
                    type=EmergencyType.FIRE,
                    status=EmergencyStatus.CANCELLED,
                    location_lat=16.8661,
                    location_lng=96.1951,
                    created_at=datetime.now(timezone.utc) - timedelta(minutes=2),
                )
                db.add(e)
            await db.commit()

            result = await evaluate_cancellation_abuse(user, db)
            self.assertIsNotNone(result)
            self.assertEqual(result["suspension_tier"], 3)
            self.assertEqual(user.suspension_count, 3)
            self.assertGreater(user.remaining_suspension_seconds, 86400 * 36000)  # ~100 years
            self.assertIn("3rd Offense", user.suspension_reason)

    async def test_blocked_sos_creation_during_suspension(self):
        """Verify suspended user cannot create new SOS and receives remaining seconds in 403."""
        async with self.session_factory() as db:
            user = await db.get(Account, self.user.id)
            user.is_suspended = True
            user.suspended_until = datetime.now(timezone.utc) + timedelta(hours=12)
            user.suspension_count = 1
            user.suspension_reason = "1st Offense suspension"
            await db.commit()

            with self.assertRaises(HTTPException) as ctx:
                await check_sos_limit(user.id, db, account=user)
            self.assertEqual(ctx.exception.status_code, 403)
            self.assertIn("currently suspended", ctx.exception.detail)

    async def test_auto_reactivation_after_suspension_expires(self):
        """Verify expired suspension automatically reactivates on access."""
        async with self.session_factory() as db:
            user = await db.get(Account, self.user.id)
            # Set suspension expired 1 hour ago
            user.is_suspended = True
            user.suspended_until = datetime.now(timezone.utc) - timedelta(hours=1)
            user.suspension_count = 1
            user.suspension_reason = "Expired 1-day suspension"
            await db.commit()

            # Account is_currently_suspended should evaluate to False
            self.assertFalse(user.is_currently_suspended)
            self.assertEqual(user.remaining_suspension_seconds, 0)

    async def test_admin_unsuspend_and_manual_suspend_lifecycle(self):
        """Verify admin can view, unsuspend, and manually suspend users."""
        async with self.session_factory() as db:
            admin_acc = await db.get(Account, self.admin.id)
            user_acc = await db.get(Account, self.user.id)

            # 1. Admin manual suspend for 5 days
            suspend_req = AdminSuspendUserRequest(duration_days=5, reason="Testing admin suspend")
            sus_res = await admin_suspend_user(str(user_acc.id), suspend_req, current_user=admin_acc, db=db)
            self.assertTrue(sus_res["is_suspended"])

            # 2. Check admin list_users with status filter
            users_list = await list_users(status_filter="suspended", current_user=admin_acc, db=db)
            self.assertTrue(any(u["account_id"] == str(user_acc.id) for u in users_list))

            # 3. Admin lifts / deactivates suspension
            unsus_res = await admin_unsuspend_user(str(user_acc.id), current_user=admin_acc, db=db)
            self.assertFalse(unsus_res["is_suspended"])

            # Check user in DB is now active and unsuspended
            reloaded_user = await db.get(Account, self.user.id)
            self.assertFalse(reloaded_user.is_suspended)
            self.assertIsNone(reloaded_user.suspended_until)


if __name__ == "__main__":
    unittest.main()
