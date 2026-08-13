"""Authentication service — registration and login logic."""

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException

from app.models.account import Account, RoleEnum
from app.models.user_profile import UserProfile
from app.models.organization import Organization
from app.core.security import hash_password, verify_password, create_access_token
from app.core.privacy import encrypt_field
from app.schemas.auth import (
    RegisterUserRequest, RegisterOrgRequest, LoginRequest, TokenResponse,
)


async def register_user(data: RegisterUserRequest, db: AsyncSession) -> TokenResponse:
    """Register a new user account with profile."""
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
    await db.commit()

    role_val = str(RoleEnum.USER.value).lower()
    token = create_access_token(
        data={"sub": str(account.id), "role": role_val}
    )
    return TokenResponse(
        access_token=token, role=role_val, user_id=str(account.id)
    )


async def register_organization(
    data: RegisterOrgRequest, db: AsyncSession
) -> TokenResponse:
    """Register a new organization account."""
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
    await db.commit()

    role_val = str(RoleEnum.ORGANIZATION.value).lower()
    token = create_access_token(
        data={"sub": str(account.id), "role": role_val}
    )
    return TokenResponse(
        access_token=token,
        role=role_val,
        user_id=str(account.id),
    )


async def login(data: LoginRequest, db: AsyncSession) -> TokenResponse:
    """Authenticate and return a JWT token."""
    clean_email = data.email.lower().strip()
    result = await db.execute(select(Account).where(func.lower(Account.email) == clean_email))
    account = result.scalar_one_or_none()

    if not account or not verify_password(data.password, account.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if not account.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    role_val = str(account.role.value if hasattr(account.role, 'value') else account.role).lower()
    token = create_access_token(
        data={"sub": str(account.id), "role": role_val}
    )
    return TokenResponse(
        access_token=token, role=role_val, user_id=str(account.id)
    )
