"""Authentication service — registration and login logic with multi-device session handling."""

from typing import Optional
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException

from app.models.account import Account, RoleEnum
from app.models.user_profile import UserProfile
from app.models.organization import Organization
from app.core.security import hash_password, verify_password
from app.core.privacy import encrypt_field
from app.schemas.auth import (
    RegisterUserRequest, RegisterOrgRequest, LoginRequest, TokenResponse,
)
from app.services.session_service import create_user_session


async def register_user(
    data: RegisterUserRequest,
    db: AsyncSession,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> TokenResponse:
    """Register a new user account with profile and initial device session."""
    clean_email = data.email.lower().strip()
    result = await db.execute(select(Account).where(func.lower(Account.email) == clean_email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="This email address is already registered. Please login instead."
        )

    account = Account(
        email=clean_email,
        hashed_password=hash_password(data.password),
        role=RoleEnum.USER,
    )
    db.add(account)
    await db.flush()

    enc_phone, phone_salt = encrypt_field(data.phone_number)

    profile = UserProfile(
        account_id=account.id,
        full_name=data.full_name,
        phone_number=enc_phone or data.phone_number,
        phone_salt=phone_salt,
        blood_type=data.blood_type,
        medical_conditions=data.medical_conditions,
        emergency_contacts=data.emergency_contacts,
    )
    db.add(profile)
    await db.flush()

    session_data = await create_user_session(
        account=account,
        db=db,
        device_id=data.device_id,
        device_name=data.device_name,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    return TokenResponse(**session_data)


async def register_organization(
    data: RegisterOrgRequest,
    db: AsyncSession,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> TokenResponse:
    """Register a new organization account and initial device session."""
    clean_email = data.email.lower().strip()
    result = await db.execute(select(Account).where(func.lower(Account.email) == clean_email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="This email address is already registered. Please login instead."
        )

    account = Account(
        email=clean_email,
        hashed_password=hash_password(data.password),
        role=RoleEnum.ORGANIZATION,
    )
    db.add(account)
    await db.flush()

    enc_phone, phone_salt = encrypt_field(data.phone_number)

    org = Organization(
        account_id=account.id,
        org_name=data.org_name,
        phone_number=enc_phone or data.phone_number,
        phone_salt=phone_salt,
        geo_lat=data.geo_lat,
        geo_lng=data.geo_lng,
        coverage_radius_km=data.coverage_radius_km,
    )
    db.add(org)
    await db.flush()

    session_data = await create_user_session(
        account=account,
        db=db,
        device_id=data.device_id,
        device_name=data.device_name,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    return TokenResponse(**session_data)


async def login(
    data: LoginRequest,
    db: AsyncSession,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> TokenResponse:
    """Authenticate, enforce device limits, and return a new session with JWT and refresh token."""
    clean_email = data.email.lower().strip()
    result = await db.execute(select(Account).where(func.lower(Account.email) == clean_email))
    account = result.scalar_one_or_none()

    if not account or not verify_password(data.password, account.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if not account.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    session_data = await create_user_session(
        account=account,
        db=db,
        device_id=data.device_id,
        device_name=data.device_name,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    return TokenResponse(**session_data)

