"""
Unit test suite verifying security hardening and vulnerability remediations:
1. Emergency IDOR authorization & mutation restrictions
2. Daily SOS abuse rate limiting (check_sos_limit)
3. OTP brute-force attempt lockout & invalidation
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
from app.config import settings
from app.models import Account, RoleEnum, Emergency, EmergencyType, EmergencyStatus, PasswordResetOTP
from app.core.security import hash_password
from app.core.abuse import check_sos_limit
from app.api.auth import verify_otp_endpoint, _otp_failed_attempts
from app.schemas.auth import VerifyOTPRequest
from app.api.emergency import get_emergency, complete_emergency, cancel_emergency_by_id


class TestSecurityRemediations(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
        self.session_factory = async_sessionmaker(self.engine, class_=AsyncSession, expire_on_commit=False)

        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        # Clear global OTP failed attempts tracker between tests
        _otp_failed_attempts.clear()

        # Seed Accounts
        async with self.session_factory() as db:
            self.victim = Account(
                id=uuid.uuid4(),
                email="victim@test.com",
                hashed_password=hash_password("Pass1234"),
                role=RoleEnum.USER,
                is_active=True,
            )
            self.attacker = Account(
                id=uuid.uuid4(),
                email="attacker@test.com",
                hashed_password=hash_password("Pass1234"),
                role=RoleEnum.USER,
                is_active=True,
            )
            self.org = Account(
                id=uuid.uuid4(),
                email="rescue_org@test.com",
                hashed_password=hash_password("Pass1234"),
                role=RoleEnum.ORGANIZATION,
                is_active=True,
            )
            self.admin = Account(
                id=uuid.uuid4(),
                email="admin@test.com",
                hashed_password=hash_password("Pass1234"),
                role=RoleEnum.ADMIN,
                is_active=True,
            )
            db.add_all([self.victim, self.attacker, self.org, self.admin])
            await db.commit()

            # Seed an Emergency for victim assigned to org
            self.emergency = Emergency(
                id=uuid.uuid4(),
                user_id=self.victim.id,
                type=EmergencyType.MEDICAL,
                status=EmergencyStatus.PENDING,
                assigned_org_id=self.org.id,
                location_lat=16.8661,
                location_lng=96.1951,
            )
            db.add(self.emergency)
            await db.commit()

    async def asyncTearDown(self):
        await self.engine.dispose()

    async def test_idor_get_emergency_denied_for_unrelated_user(self):
        """Verify unrelated user cannot read victim's emergency details (IDOR prevention)."""
        async with self.session_factory() as db:
            with self.assertRaises(HTTPException) as ctx:
                await get_emergency(
                    emergency_id=str(self.emergency.id),
                    current_user=self.attacker,
                    db=db,
                )
            self.assertEqual(ctx.exception.status_code, 403)
            self.assertIn("Access denied", ctx.exception.detail)

    async def test_idor_get_emergency_allowed_for_victim_org_and_admin(self):
        """Verify victim, assigned org, and admin can view the emergency."""
        async with self.session_factory() as db:
            # Victim can access
            res_v = await get_emergency(str(self.emergency.id), current_user=self.victim, db=db)
            self.assertEqual(res_v.id, str(self.emergency.id))

            # Assigned Org can access
            res_o = await get_emergency(str(self.emergency.id), current_user=self.org, db=db)
            self.assertEqual(res_o.id, str(self.emergency.id))

            # Admin can access
            res_a = await get_emergency(str(self.emergency.id), current_user=self.admin, db=db)
            self.assertEqual(res_a.id, str(self.emergency.id))

    async def test_emergency_complete_unauthorized_user_blocked(self):
        """Verify unrelated user cannot complete someone else's emergency."""
        async with self.session_factory() as db:
            with self.assertRaises(HTTPException) as ctx:
                await complete_emergency(
                    emergency_id=str(self.emergency.id),
                    current_user=self.attacker,
                    db=db,
                )
            self.assertEqual(ctx.exception.status_code, 403)

    async def test_emergency_cancel_unauthorized_user_blocked(self):
        """Verify unrelated user cannot cancel someone else's emergency."""
        async with self.session_factory() as db:
            with self.assertRaises(HTTPException) as ctx:
                await cancel_emergency_by_id(
                    emergency_id=str(self.emergency.id),
                    current_user=self.attacker,
                    db=db,
                )
            self.assertEqual(ctx.exception.status_code, 403)

    async def test_sos_daily_rate_limiting(self):
        """Verify check_sos_limit raises 429 when max daily limit is reached."""
        async with self.session_factory() as db:
            original_max = settings.MAX_SOS_PER_DAY
            try:
                settings.MAX_SOS_PER_DAY = 3
                # Create 3 emergencies
                for _ in range(3):
                    e = Emergency(
                        user_id=self.victim.id,
                        type=EmergencyType.ACCIDENT,
                        status=EmergencyStatus.COMPLETED,
                        location_lat=16.8,
                        location_lng=96.1,
                    )
                    db.add(e)
                await db.commit()

                with self.assertRaises(HTTPException) as ctx:
                    await check_sos_limit(self.victim.id, db)
                self.assertEqual(ctx.exception.status_code, 429)
                self.assertIn("Daily SOS limit reached", ctx.exception.detail)
            finally:
                settings.MAX_SOS_PER_DAY = original_max

    async def test_otp_brute_force_lockout_and_invalidation(self):
        """Verify 5 failed OTP attempts triggers 429 and invalidates the OTP."""
        async with self.session_factory() as db:
            otp = PasswordResetOTP(
                email="victim@test.com",
                otp_code="123456",
                expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
                is_used=False,
            )
            db.add(otp)
            await db.commit()

            # Attempt 4 wrong codes -> 400 Bad Request
            for i in range(1, 5):
                with self.assertRaises(HTTPException) as ctx:
                    await verify_otp_endpoint(
                        VerifyOTPRequest(email="victim@test.com", otp=f"00000{i}"),
                        db=db,
                    )
                self.assertEqual(ctx.exception.status_code, 400)
                self.assertIn("attempts remaining", ctx.exception.detail)

            # Attempt 5th wrong code -> 429 Too Many Requests & invalidation
            with self.assertRaises(HTTPException) as ctx:
                await verify_otp_endpoint(
                    VerifyOTPRequest(email="victim@test.com", otp="000005"),
                    db=db,
                )
            self.assertEqual(ctx.exception.status_code, 429)
            self.assertIn("Too many failed verification attempts", ctx.exception.detail)

            # Verify OTP record is now marked as used/invalidated in DB
            db_otp = await db.get(PasswordResetOTP, otp.id)
            self.assertTrue(db_otp.is_used)


if __name__ == "__main__":
    unittest.main()
