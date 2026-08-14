"""Admin endpoints — CRUD management of rescue organizations and system accounts."""

import uuid as uuid_module
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account, RoleEnum
from app.models.organization import Organization
from app.core.security import get_current_user, hash_password
from app.core.permissions import require_role
from app.schemas.auth import validate_password
from pydantic import field_validator

router = APIRouter()


class CreateAdminOrgRequest(BaseModel):
    org_name: str
    email: EmailStr
    password: str
    phone_number: str
    geo_lat: float
    geo_lng: float
    registration_number: Optional[str] = "REG-2026-HQ"
    headquarters_address: Optional[str] = "Main HQ"
    operating_regions: Optional[str] = "Yangon"
    category: str = "Medical"
    coverage_radius_km: Optional[float] = 50.0

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password(v)


class UpdateAdminOrgRequest(BaseModel):
    org_name: Optional[str] = None
    phone_number: Optional[str] = None
    geo_lat: Optional[float] = None
    geo_lng: Optional[float] = None
    registration_number: Optional[str] = None
    headquarters_address: Optional[str] = None
    operating_regions: Optional[str] = None
    category: Optional[str] = None
    coverage_radius_km: Optional[float] = None
    status: Optional[str] = None
    is_active: Optional[bool] = None


@router.get("/organizations")
async def list_organizations(
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to list all registered rescue organizations."""
    result = await db.execute(select(Organization).options(joinedload(Organization.account)))
    orgs = result.scalars().all()

    items = []
    for org in orgs:
        acc = org.account
        items.append({
            "account_id": str(org.account_id),
            "org_name": org.org_name,
            "email": acc.email if acc else "",
            "phone_number": org.get_decrypted_phone(),
            "geo_lat": org.geo_lat,
            "geo_lng": org.geo_lng,
            "registration_number": org.registration_number,
            "headquarters_address": org.headquarters_address,
            "operating_regions": org.operating_regions,
            "category": org.category,
            "coverage_radius_km": org.coverage_radius_km,
            "status": org.status,
            "is_active": org.is_active,
        })
    return items


@router.post("/organizations", status_code=status.HTTP_201_CREATED)
async def create_organization(
    data: CreateAdminOrgRequest,
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to create a new rescue organization account."""
    existing = await db.execute(select(Account).where(Account.email == data.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    account = Account(
        email=data.email,
        hashed_password=hash_password(data.password),
        role=RoleEnum.ORGANIZATION,
    )
    db.add(account)
    await db.flush()

    org = Organization(
        account_id=account.id,
        org_name=data.org_name,
        phone_number="",
        geo_lat=data.geo_lat,
        geo_lng=data.geo_lng,
        registration_number=data.registration_number,
        headquarters_address=data.headquarters_address,
        operating_regions=data.operating_regions,
        category=data.category,
        coverage_radius_km=data.coverage_radius_km,
        status="Active",
        is_active=True,
    )
    org.set_salted_phone(data.phone_number)
    db.add(org)
    await db.commit()

    return {
        "message": "Organization created successfully",
        "account_id": str(account.id),
        "org_name": org.org_name,
    }


@router.put("/organizations/{account_id}")
async def update_organization(
    account_id: str,
    data: UpdateAdminOrgRequest,
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to update an organization account."""
    try:
        acc_uuid = uuid_module.UUID(account_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid account ID")

    result = await db.execute(select(Organization).where(Organization.account_id == acc_uuid))
    org = result.scalar_one_or_none()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")

    if data.org_name is not None:
        org.org_name = data.org_name
    if data.phone_number is not None:
        org.set_salted_phone(data.phone_number)
    if data.geo_lat is not None:
        org.geo_lat = data.geo_lat
    if data.geo_lng is not None:
        org.geo_lng = data.geo_lng
    if data.registration_number is not None:
        org.registration_number = data.registration_number
    if data.headquarters_address is not None:
        org.headquarters_address = data.headquarters_address
    if data.operating_regions is not None:
        org.operating_regions = data.operating_regions
    if data.category is not None:
        org.category = data.category
    if data.coverage_radius_km is not None:
        org.coverage_radius_km = data.coverage_radius_km
    if data.status is not None:
        org.status = data.status
    if data.is_active is not None:
        org.is_active = data.is_active

    await db.commit()
    return {"message": "Organization updated successfully"}


@router.delete("/organizations/{account_id}")
async def delete_organization(
    account_id: str,
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to delete an organization account."""
    try:
        acc_uuid = uuid_module.UUID(account_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid account ID")

    result = await db.execute(select(Account).where(Account.id == acc_uuid))
    acc = result.scalar_one_or_none()
    if not acc:
        raise HTTPException(status_code=404, detail="Organization account not found")

    await db.delete(acc)
    await db.commit()
    return {"message": "Organization account deleted successfully"}


@router.get("/emergencies")
async def list_emergencies(
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to list all SOS emergencies with eagerly loaded user and org details (O(1) queries)."""
    from app.models.emergency import Emergency
    from app.schemas.emergency import AdminEmergencyRecord
    from sqlalchemy.orm import joinedload
    
    result = await db.execute(
        select(Emergency)
        .options(joinedload(Emergency.user), joinedload(Emergency.assigned_org))
        .order_by(Emergency.created_at.desc())
        .limit(100)
    )
    emergencies = result.scalars().all()
    
    records = []
    for e in emergencies:
        profile = e.user.user_profile
        records.append(
            AdminEmergencyRecord(
                emergency_id=str(e.id),
                user_name=profile.full_name if profile else "Unknown",
                user_phone=profile.phone_number if profile else "",
                blood_type=profile.blood_type or "Unknown",
                medical_conditions=profile.medical_conditions or "None",
                type=e.type.value,
                status=e.status.value,
                assigned_org_name=e.assigned_org.org_name if e.assigned_org else "Unassigned",
                location_lat=e.location_lat,
                location_lng=e.location_lng,
                created_at=e.created_at,
            )
        )
    return records


# ── Session Monitoring & Control ──────────────────────────────────────────

@router.get("/sessions")
async def list_admin_sessions(
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to monitor all active and recent user device sessions."""
    from app.services.session_service import admin_list_sessions
    return await admin_list_sessions(db=db, limit=200)


@router.get("/sessions/user/{user_id}")
async def list_user_sessions_admin(
    user_id: str,
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to inspect sessions of a specific user account."""
    from app.services.session_service import admin_list_sessions
    try:
        u_uuid = uuid_module.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    return await admin_list_sessions(db=db, user_id=u_uuid, limit=100)


@router.post("/sessions/{session_id}/terminate")
async def terminate_session_admin(
    session_id: str,
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to forcibly revoke/terminate any active session."""
    from app.models.session import UserSession
    from sqlalchemy import update
    try:
        s_uuid = uuid_module.UUID(session_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid session ID format")

    result = await db.execute(
        update(UserSession)
        .where(UserSession.id == s_uuid)
        .values(is_active=False)
    )
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"message": "Session terminated successfully"}


@router.post("/sessions/user/{user_id}/terminate-all")
async def terminate_all_user_sessions_admin(
    user_id: str,
    current_user: Account = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to forcibly revoke/terminate all active sessions for a user."""
    from app.services.session_service import logout_all_user_sessions
    try:
        u_uuid = uuid_module.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user ID format")

    count = await logout_all_user_sessions(u_uuid, db)
    return {"message": f"Successfully terminated {count} session(s) for user"}

