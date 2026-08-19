"""
Unit test for verifying Forgot Password, OTP verification, and Password Reset lifecycle.
"""

import sys
import os
import unittest
from unittest.mock import AsyncMock, patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.database import Base
from app.models import Account, RoleEnum, PasswordResetOTP
from app.core.security import hash_password, verify_password
from app.api.auth import (
    forgot_password_endpoint,
    verify_otp_endpoint,
    reset_password_endpoint,
)
from app.schemas.auth import (
    ForgotPasswordRequest,
    VerifyOTPRequest,
    ResetPasswordRequest,
)


class TestForgotPasswordLifecycle(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
        self.session_factory = async_sessionmaker(self.engine, class_=AsyncSession, expire_on_commit=False)

        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with self.session_factory() as db:
            acc = Account(
                email="victim@gmail.com",
                hashed_password=hash_password("OldPassword123"),
                role=RoleEnum.USER,
                is_active=True,
            )
            db.add(acc)
            await db.commit()
            self.user_id = acc.id

    async def asyncTearDown(self):
        await self.engine.dispose()

    async def test_forgot_password_otp_and_reset_flow_success(self):
        # 1. Request OTP for registered email
        async with self.session_factory() as db:
            with patch("app.api.auth.send_password_reset_otp_email", new_callable=AsyncMock) as mock_send_email:
                res = await forgot_password_endpoint(
                    ForgotPasswordRequest(email="victim@gmail.com"),
                    db=db,
                )
                self.assertIn("verification code has been sent", res["message"])
                mock_send_email.assert_awaited_once()

        # 2. Extract generated OTP from database
        async with self.session_factory() as db:
            otp_res = await db.execute(
                select(PasswordResetOTP).where(PasswordResetOTP.email == "victim@gmail.com")
            )
            otp_record = otp_res.scalar_one()
            self.assertEqual(len(otp_record.otp_code), 6)
            self.assertFalse(otp_record.is_used)
            generated_otp = otp_record.otp_code

        # 3. Verify OTP
        async with self.session_factory() as db:
            verify_res = await verify_otp_endpoint(
                VerifyOTPRequest(email="victim@gmail.com", otp=generated_otp),
                db=db,
            )
            self.assertTrue(verify_res["valid"])

        # 4. Reset Password with new credentials
        async with self.session_factory() as db:
            reset_res = await reset_password_endpoint(
                ResetPasswordRequest(
                    email="victim@gmail.com",
                    otp=generated_otp,
                    new_password="BrandNewPassword456",
                ),
                db=db,
            )
            self.assertIn("Password reset successfully", reset_res["message"])

        # 5. Verify database password was updated and OTP was marked used
        async with self.session_factory() as db:
            acc = await db.get(Account, self.user_id)
            self.assertTrue(verify_password("BrandNewPassword456", acc.hashed_password))
            self.assertFalse(verify_password("OldPassword123", acc.hashed_password))

            otp_res = await db.execute(
                select(PasswordResetOTP).where(PasswordResetOTP.email == "victim@gmail.com")
            )
            otp_record = otp_res.scalar_one()
            self.assertTrue(otp_record.is_used)

    async def test_invalid_otp_fails(self):
        async with self.session_factory() as db:
            from fastapi import HTTPException
            with self.assertRaises(HTTPException) as ctx:
                await verify_otp_endpoint(
                    VerifyOTPRequest(email="victim@gmail.com", otp="999999"),
                    db=db,
                )
            self.assertEqual(ctx.exception.status_code, 400)

    async def test_expired_otp_fails(self):
        from datetime import datetime, timezone, timedelta
        from fastapi import HTTPException

        async with self.session_factory() as db:
            # Create an OTP expired 1 second ago
            expired_otp = PasswordResetOTP(
                email="victim@gmail.com",
                otp_code="123456",
                expires_at=datetime.now(timezone.utc) - timedelta(seconds=1),
                is_used=False,
            )
            db.add(expired_otp)
            await db.commit()

        async with self.session_factory() as db:
            with self.assertRaises(HTTPException) as ctx:
                await verify_otp_endpoint(
                    VerifyOTPRequest(email="victim@gmail.com", otp="123456"),
                    db=db,
                )
            self.assertEqual(ctx.exception.status_code, 400)
            self.assertIn("expired", ctx.exception.detail)


if __name__ == "__main__":
    unittest.main()

