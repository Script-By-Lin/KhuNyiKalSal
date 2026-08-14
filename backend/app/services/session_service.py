"""Session service — device limits, token generation, session lifecycle, emergency locks."""

import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, List

from fastapi import HTTPException, status
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.account import Account, RoleEnum
from app.models.session import UserSession
from app.core.security import (
    create_access_token,
    generate_refresh_token,
    hash_token,
)


async def enforce_device_limits(account: Account, db: AsyncSession) -> None:
    """
    Enforce role-specific session and device limits:
    - VOLUNTEER: Only ONE active session allowed. Deactivate all existing sessions.
    - USER: Allow max 3 active sessions. Deactivate oldest if limit reached.
    - ORGANIZATION: Multiple devices allowed (no strict limit).
    """
    role = account.role
    role_str = role.value if hasattr(role, "value") else str(role)

    if role_str.upper() == RoleEnum.VOLUNTEER.value:
        # Deactivate ALL previous sessions for volunteer
        await db.execute(
            update(UserSession)
            .where(
                UserSession.user_id == account.id,
                UserSession.is_active == True,
            )
            .values(is_active=False)
        )
        await db.flush()

    elif role_str.upper() == RoleEnum.USER.value:
        # Fetch all currently active sessions for user, oldest first
        result = await db.execute(
            select(UserSession)
            .where(
                UserSession.user_id == account.id,
                UserSession.is_active == True,
            )
            .order_by(UserSession.created_at.asc())
        )
        active_sessions = result.scalars().all()

        # If reaching or exceeding max limit (3), deactivate oldest sessions
        max_allowed = settings.MAX_USER_SESSIONS
        if len(active_sessions) >= max_allowed:
            overflow_count = len(active_sessions) - max_allowed + 1
            oldest_to_remove = active_sessions[:overflow_count]
            for s in oldest_to_remove:
                s.is_active = False
            await db.flush()


async def create_user_session(
    account: Account,
    db: AsyncSession,
    device_id: Optional[str] = None,
    device_name: Optional[str] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> dict:
    """Create a new session record, generate access + refresh tokens, and enforce device limits."""
    # 1. Enforce device limit rules for account role
    await enforce_device_limits(account, db)

    # 2. Generate raw tokens
    raw_refresh_token = generate_refresh_token()
    refresh_token_hashed = hash_token(raw_refresh_token)

    # 3. Create session record
    session = UserSession(
        user_id=account.id,
        device_id=device_id or "unknown_device",
        device_name=device_name or "Mobile App",
        refresh_token_hash=refresh_token_hashed,
        ip_address=ip_address,
        user_agent=user_agent,
        is_active=True,
        created_at=datetime.now(timezone.utc),
        last_used_at=datetime.now(timezone.utc),
    )
    db.add(session)
    await db.flush()

    # 4. Generate JWT access token with session_id embedded
    role_val = str(account.role.value if hasattr(account.role, "value") else account.role).lower()
    access_token = create_access_token(
        data={
            "sub": str(account.id),
            "session_id": str(session.id),
            "role": role_val,
        }
    )

    await db.commit()

    return {
        "access_token": access_token,
        "refresh_token": raw_refresh_token,
        "token_type": "bearer",
        "role": role_val,
        "user_id": str(account.id),
        "session_id": str(session.id),
    }


async def refresh_user_session(
    refresh_token_plain: str,
    db: AsyncSession,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> dict:
    """Validate refresh token hash and issue a new access token for an active session."""
    token_hash = hash_token(refresh_token_plain)

    result = await db.execute(
        select(UserSession).where(
            UserSession.refresh_token_hash == token_hash,
            UserSession.is_active == True,
        )
    )
    session = result.scalar_one_or_none()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or deactivated refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check inactivity timeout (24h)
    cutoff = datetime.now(timezone.utc) - timedelta(
        hours=settings.SESSION_INACTIVITY_HOURS
    )
    last_used = session.last_used_at
    if last_used.tzinfo is None:
        last_used = last_used.replace(tzinfo=timezone.utc)

    if last_used < cutoff:
        session.is_active = False
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired due to inactivity. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Fetch associated account
    acc_result = await db.execute(
        select(Account).where(Account.id == session.user_id)
    )
    account = acc_result.scalar_one_or_none()

    if not account or not account.is_active:
        session.is_active = False
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    # Update session activity
    session.last_used_at = datetime.now(timezone.utc)
    if ip_address:
        session.ip_address = ip_address
    if user_agent:
        session.user_agent = user_agent

    role_val = str(account.role.value if hasattr(account.role, "value") else account.role).lower()
    new_access_token = create_access_token(
        data={
            "sub": str(account.id),
            "session_id": str(session.id),
            "role": role_val,
        }
    )

    await db.commit()

    return {
        "access_token": new_access_token,
        "refresh_token": refresh_token_plain,
        "token_type": "bearer",
        "role": role_val,
        "user_id": str(account.id),
        "session_id": str(session.id),
    }


async def logout_single_session(
    session_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession,
) -> bool:
    """Deactivate a single session record."""
    result = await db.execute(
        update(UserSession)
        .where(
            UserSession.id == session_id,
            UserSession.user_id == user_id,
        )
        .values(is_active=False)
    )
    await db.commit()
    return result.rowcount > 0


async def logout_all_user_sessions(
    user_id: uuid.UUID,
    db: AsyncSession,
    except_session_id: Optional[uuid.UUID] = None,
) -> int:
    """Deactivate all active sessions for a user (optionally keeping the current session)."""
    stmt = update(UserSession).where(
        UserSession.user_id == user_id,
        UserSession.is_active == True,
    )
    if except_session_id:
        stmt = stmt.where(UserSession.id != except_session_id)

    stmt = stmt.values(is_active=False)
    result = await db.execute(stmt)
    await db.commit()
    return result.rowcount


async def lock_emergency_session(
    user_id: uuid.UUID,
    current_session_id: Optional[uuid.UUID],
    db: AsyncSession,
) -> None:
    """
    Emergency session lock: when an SOS is triggered, lock the user to the current session
    and deactivate all other sessions to avoid duplicate requests and ensure consistency.
    """
    if not current_session_id:
        return

    await db.execute(
        update(UserSession)
        .where(
            UserSession.user_id == user_id,
            UserSession.id != current_session_id,
            UserSession.is_active == True,
        )
        .values(is_active=False)
    )
    await db.commit()


async def list_user_sessions(
    user_id: uuid.UUID,
    current_session_id: Optional[uuid.UUID],
    db: AsyncSession,
) -> List[dict]:
    """List all sessions for a user, indicating which is the current device session."""
    result = await db.execute(
        select(UserSession)
        .where(UserSession.user_id == user_id)
        .order_by(UserSession.last_used_at.desc())
    )
    sessions = result.scalars().all()

    return [
        {
            "session_id": str(s.id),
            "device_id": s.device_id,
            "device_name": s.device_name or "Unknown Device",
            "ip_address": s.ip_address or "Unknown IP",
            "user_agent": s.user_agent,
            "is_active": s.is_active,
            "created_at": s.created_at,
            "last_used_at": s.last_used_at,
            "is_current": s.id == current_session_id if current_session_id else False,
        }
        for s in sessions
    ]


async def admin_list_sessions(
    db: AsyncSession,
    user_id: Optional[uuid.UUID] = None,
    limit: int = 100,
) -> List[dict]:
    """Admin monitoring endpoint to view active and recent sessions across all users."""
    stmt = (
        select(UserSession, Account)
        .join(Account, UserSession.user_id == Account.id)
        .order_by(UserSession.last_used_at.desc())
        .limit(limit)
    )
    if user_id:
        stmt = stmt.where(UserSession.user_id == user_id)

    result = await db.execute(stmt)
    rows = result.all()

    items = []
    for s, acc in rows:
        role_val = acc.role.value if hasattr(acc.role, "value") else str(acc.role)
        items.append({
            "session_id": str(s.id),
            "user_id": str(acc.id),
            "email": acc.email,
            "role": role_val,
            "device_id": s.device_id,
            "device_name": s.device_name or "Unknown Device",
            "ip_address": s.ip_address or "Unknown IP",
            "user_agent": s.user_agent,
            "is_active": s.is_active,
            "created_at": s.created_at,
            "last_used_at": s.last_used_at,
        })
    return items
