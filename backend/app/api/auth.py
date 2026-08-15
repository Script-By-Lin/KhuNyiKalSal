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
from app.core.security import get_current_user, get_current_session_id, verify_password, hash_password
from app.models.account import Account

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

