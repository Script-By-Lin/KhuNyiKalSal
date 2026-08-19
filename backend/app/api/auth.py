"""Authentication endpoints — register (user / org), login, refresh token, and device session control."""

import uuid
from typing import List , Optional
from fastapi import APIRouter, Depends, Request, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.auth import (
    RegisterUserRequest,
    RegisterOrgRequest,
    LoginRequest,
    RefreshTokenRequest,
    ChangePasswordRequest,
    ForgotPasswordRequest,
    VerifyOTPRequest,
    ResetPasswordRequest,
    TokenResponse,
    AccountResponse,
    SessionItemResponse,
)
from app.services.auth_service import register_user, register_organization, login
from app.services.session_service import (
    refresh_user_session,
    logout_single_session,
    logout_all_user_sessions,
    list_user_sessions,
)
from app.services.email_service import send_password_reset_otp_email
from app.core.security import get_current_user, get_current_session_id, verify_password, hash_password
from app.models.account import Account
from app.models.password_reset_otp import PasswordResetOTP
from app.config import settings
import secrets
from datetime import datetime, timezone, timedelta
from sqlalchemy import select, func

router = APIRouter()


def _get_client_info(request: Request) -> tuple[str, str]:
    """Helper to extract IP address and User-Agent from incoming request."""
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        ip = forwarded_for.split(",")[0].strip()
    elif request.client:
        ip = request.client.host
    else:
        ip = "unknown_ip"
    user_agent = request.headers.get("user-agent", "Unknown Device")
    return ip, user_agent


@router.post("/register/user", response_model=TokenResponse)
async def register_user_endpoint(
    data: RegisterUserRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    ip, user_agent = _get_client_info(request)
    return await register_user(data, db, ip_address=ip, user_agent=user_agent)


@router.post("/register/organization", response_model=TokenResponse)
async def register_org_endpoint(
    data: RegisterOrgRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    ip, user_agent = _get_client_info(request)
    return await register_organization(data, db, ip_address=ip, user_agent=user_agent)


@router.post("/login", response_model=TokenResponse)
async def login_endpoint(
    data: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    ip, user_agent = _get_client_info(request)
    return await login(data, db, ip_address=ip, user_agent=user_agent)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_endpoint(
    data: RefreshTokenRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Client exchanges valid refresh_token for a new access_token."""
    ip, user_agent = _get_client_info(request)
    return await refresh_user_session(
        refresh_token_plain=data.refresh_token,
        db=db,
        ip_address=ip,
        user_agent=user_agent,
    )


@router.post("/logout")
async def logout_endpoint(
    current_user: Account = Depends(get_current_user),
    current_session_id: Optional[uuid.UUID] = Depends(get_current_session_id),
    db: AsyncSession = Depends(get_db),
):
    """Single device logout — deactivate the caller's current session."""
    if current_session_id:
        await logout_single_session(current_session_id, current_user.id, db)
    return {"message": "Logged out successfully from this device"}


@router.post("/logout-all")
async def logout_all_endpoint(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Logout from all devices — deactivates all active sessions for current user."""
    count = await logout_all_user_sessions(current_user.id, db)
    return {"message": f"Successfully logged out of {count} devices"}


@router.get("/sessions", response_model=List[SessionItemResponse])
async def get_my_sessions(
    current_user: Account = Depends(get_current_user),
    current_session_id: Optional[uuid.UUID] = Depends(get_current_session_id),
    db: AsyncSession = Depends(get_db),
):
    """List all active and recent device sessions for the authenticated user."""
    return await list_user_sessions(current_user.id, current_session_id, db)


@router.delete("/sessions/{session_id}")
async def revoke_session_endpoint(
    session_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke/terminate a specific device session."""
    try:
        s_uuid = uuid.UUID(session_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid session ID format")

    success = await logout_single_session(s_uuid, current_user.id, db)
    if not success:
        raise HTTPException(status_code=404, detail="Session not found or already deactivated")

    return {"message": "Session terminated successfully"}


@router.get("/me", response_model=AccountResponse)
async def get_me(current_user: Account = Depends(get_current_user)):
    return AccountResponse(
        id=str(current_user.id),
        email=current_user.email,
        role=current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role),
        is_active=current_user.is_active,
    )


@router.post("/change-password")
async def change_password_endpoint(
    data: ChangePasswordRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Change the account password with validation and current password verification."""
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect. Please verify and try again.",
        )
    
    if data.current_password == data.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from your current password.",
        )

    current_user.hashed_password = hash_password(data.new_password)
    await db.commit()
    return {"message": "Password changed successfully. Please remember your new password."}


@router.post("/forgot-password")
async def forgot_password_endpoint(
    data: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Request a 6-digit OTP code sent to the user's registered Gmail/email address.
    """
    target_email = data.email.lower().strip()
    
    # Check if account exists
    acc_res = await db.execute(
        select(Account).where(func.lower(Account.email) == target_email)
    )
    acc = acc_res.scalar_one_or_none()
    if not acc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No registered account found with email '{data.email}'. Please check your spelling or register.",
        )

    if not acc.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been deactivated. Please contact emergency administrator support.",
        )

    # Generate 6-digit secure numeric OTP
    otp_code = f"{secrets.randbelow(900000) + 100000}"
    validity_sec = settings.OTP_VALIDITY_SECONDS
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=validity_sec)

    # Store OTP in database
    otp_record = PasswordResetOTP(
        email=target_email,
        otp_code=otp_code,
        expires_at=expires_at,
        is_used=False,
    )
    db.add(otp_record)
    await db.commit()

    # Dispatch email (via EmailJS API or SMTP)
    await send_password_reset_otp_email(target_email, otp_code, validity_seconds=validity_sec)

    return {
        "message": f"A 6-digit verification code has been sent to {target_email}. Valid for {validity_sec} seconds.",
        "email": target_email,
        "validity_seconds": validity_sec,
    }


@router.post("/verify-otp")
async def verify_otp_endpoint(
    data: VerifyOTPRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Verify that the provided 6-digit OTP is valid and not expired.
    """
    target_email = data.email.lower().strip()
    now_utc = datetime.now(timezone.utc)

    res = await db.execute(
        select(PasswordResetOTP)
        .where(
            func.lower(PasswordResetOTP.email) == target_email,
            PasswordResetOTP.otp_code == data.otp.strip(),
            PasswordResetOTP.is_used == False,
            PasswordResetOTP.expires_at >= now_utc,
        )
        .order_by(PasswordResetOTP.created_at.desc())
    )
    otp_record = res.scalar_one_or_none()
    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code. Please request a new code.",
        )

    return {
        "message": "Verification code verified successfully.",
        "valid": True,
    }


@router.post("/reset-password")
async def reset_password_endpoint(
    data: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Reset user password using verified 6-digit OTP code and invalidate previous device sessions.
    """
    target_email = data.email.lower().strip()
    now_utc = datetime.now(timezone.utc)

    # Find valid unexpired OTP
    res = await db.execute(
        select(PasswordResetOTP)
        .where(
            func.lower(PasswordResetOTP.email) == target_email,
            PasswordResetOTP.otp_code == data.otp.strip(),
            PasswordResetOTP.is_used == False,
            PasswordResetOTP.expires_at >= now_utc,
        )
        .order_by(PasswordResetOTP.created_at.desc())
    )
    otp_record = res.scalar_one_or_none()
    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code. Please request a new code.",
        )

    # Find Account
    acc_res = await db.execute(
        select(Account).where(func.lower(Account.email) == target_email)
    )
    acc = acc_res.scalar_one_or_none()
    if not acc:
        raise HTTPException(status_code=404, detail="Account not found.")

    # Update password
    acc.hashed_password = hash_password(data.new_password)
    
    # Mark OTP as used
    otp_record.is_used = True

    # Invalidate all existing sessions for security
    await logout_all_user_sessions(acc.id, db)

    await db.commit()

    return {
        "message": "Password reset successfully! You can now log in with your new password.",
        "email": target_email,
    }

