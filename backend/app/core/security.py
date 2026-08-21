import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security_scheme = HTTPBearer()


def _clean_password(password: str) -> str:
    """Ensure password is safe for bcrypt (max 72 bytes)."""
    return password.encode("utf-8")[:72].decode("utf-8", errors="ignore")


def hash_password(password: str) -> str:
    return pwd_context.hash(_clean_password(password))


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(_clean_password(plain_password), hashed_password)


def generate_refresh_token() -> str:
    """Generate a secure, random refresh token string."""
    return secrets.token_urlsafe(64)


def hash_token(token: str) -> str:
    """Hash a token with SHA-256 for secure database storage and lookup."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict:
    """Decode and validate a JWT access token."""
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user_and_session(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: AsyncSession = Depends(get_db),
):
    """
    FastAPI dependency: extract and validate JWT + UserSession,
    update session last_used_at, and return (Account, session_id).
    """
    from app.models.account import Account  # deferred to avoid circular import
    from app.models.session import UserSession

    token = credentials.credentials
    payload = decode_access_token(token)
    user_id: Optional[str] = payload.get("sub")
    session_id_str: Optional[str] = payload.get("session_id")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing subject",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID format in token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    result = await db.execute(select(Account).where(Account.id == user_uuid))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # Auto-reactivate user if suspension period has elapsed
    if user.suspended_until:
        now_utc = datetime.now(timezone.utc)
        target = user.suspended_until
        if target.tzinfo is None:
            target = target.replace(tzinfo=timezone.utc)
        if now_utc >= target:
            user.is_suspended = False
            user.suspended_until = None
            user.suspension_reason = None
            user.is_active = True
            await db.commit()

    if not user.is_active and not user.is_currently_suspended:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated"
        )

    # Validate session state if session_id is in JWT
    session_id: Optional[uuid.UUID] = None
    if session_id_str:
        try:
            session_uuid = uuid.UUID(session_id_str)
            session_result = await db.execute(
                select(UserSession).where(
                    UserSession.id == session_uuid,
                    UserSession.user_id == user_uuid,
                )
            )
            user_session = session_result.scalar_one_or_none()

            if not user_session or not user_session.is_active:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Session is inactive or has been logged out. Please sign in again.",
                    headers={"WWW-Authenticate": "Bearer"},
                )

            # Check inactivity timeout (24h)
            cutoff = datetime.now(timezone.utc) - timedelta(
                hours=settings.SESSION_INACTIVITY_HOURS
            )
            last_used = user_session.last_used_at
            if last_used.tzinfo is None:
                last_used = last_used.replace(tzinfo=timezone.utc)

            if last_used < cutoff:
                user_session.is_active = False
                await db.commit()
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Session expired due to inactivity. Please sign in again.",
                    headers={"WWW-Authenticate": "Bearer"},
                )

            # Refresh last_used_at only if more than 5 minutes have elapsed (throttles DB writes)
            now_utc = datetime.now(timezone.utc)
            if (now_utc - last_used) > timedelta(minutes=5):
                user_session.last_used_at = now_utc
                await db.commit()
            session_id = session_uuid

        except ValueError:
            pass

    return user, session_id


async def get_current_user(
    auth_tuple: tuple = Depends(get_current_user_and_session),
):
    """Standard dependency returning the authenticated Account."""
    user, _ = auth_tuple
    return user


async def get_current_session_id(
    auth_tuple: tuple = Depends(get_current_user_and_session),
) -> Optional[uuid.UUID]:
    """Dependency returning the active session UUID."""
    _, session_id = auth_tuple
    return session_id
