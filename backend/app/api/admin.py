"""Admin endpoints — CRUD management of rescue organizations, system accounts, emergencies, and sessions."""

import uuid as uuid_module
import re
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy import select, or_, func
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from datetime import datetime, timedelta, timezone
from app.database import get_db
from app.models.account import Account, RoleEnum
from app.models.organization import Organization
from app.models.user_profile import UserProfile
from app.models.emergency import Emergency, EmergencyStatus
from app.models.session import UserSession
from app.core.security import hash_password
from app.core.permissions import require_role
from app.schemas.auth import validate_password, validate_myanmar_phone
from app.websocket.manager import manager
from app.services.cache_service import location_cache

router = APIRouter()


class CreateAdminOrgRequest(BaseModel):
    org_name: str
    email: EmailStr
    password: str
    phone_number: str
    geo_lat: float = 16.8661
    geo_lng: float = 96.1951
    registration_number: Optional[str] = "REG-2026-HQ"
    headquarters_address: Optional[str] = "Main HQ"
    operating_regions: Optional[str] = "Yangon"
    category: str = "Medical"
    coverage_radius_km: Optional[float] = 50.0

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password(v)

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v: str) -> str:
        try:
            return validate_myanmar_phone(v)
        except Exception:
            # Fallback sanitized string if non-standard
            cleaned = v.strip().replace(" ", "").replace("-", "")
            if len(cleaned) < 5:
                raise ValueError("Phone number is too short")
            return cleaned


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
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = Query(None),
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to list all registered rescue organizations with search & pagination."""
    query = select(Organization).options(joinedload(Organization.account))

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.where(
            or_(
                func.lower(Organization.org_name).like(term),
                func.lower(Organization.category).like(term),
                func.lower(Organization.operating_regions).like(term),
                func.lower(Organization.registration_number).like(term),
            )
        )

    query = query.order_by(Organization.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    orgs = result.scalars().all()

    items = []
    for org in orgs:
        acc = org.account
        phone = ""
        try:
            phone = org.get_decrypted_phone()
        except Exception:
            phone = org.phone_number or ""

        items.append({
            "account_id": str(org.account_id),
            "org_name": org.org_name,
            "email": acc.email if acc else "",
            "phone_number": phone,
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
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to create a new rescue organization account."""
    existing = await db.execute(select(Account).where(Account.email == data.email.lower().strip()))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="An account with this email is already registered")

    account = Account(
        email=data.email.lower().strip(),
        hashed_password=hash_password(data.password),
        role=RoleEnum.ORGANIZATION,
    )
    db.add(account)
    await db.flush()

    org = Organization(
        account_id=account.id,
        org_name=data.org_name.strip(),
        phone_number="",
        geo_lat=data.geo_lat,
        geo_lng=data.geo_lng,
        registration_number=data.registration_number.strip() if data.registration_number else "REG-2026-HQ",
        headquarters_address=data.headquarters_address.strip() if data.headquarters_address else "Main HQ",
        operating_regions=data.operating_regions.strip() if data.operating_regions else "Yangon",
        category=data.category.strip() if data.category else "Medical",
        coverage_radius_km=data.coverage_radius_km or 50.0,
        status="Active",
        is_active=True,
    )
    org.set_salted_phone(data.phone_number.strip())
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
    current_user: Account = Depends(require_role("admin", "superadmin")),
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
        org.org_name = data.org_name.strip()
    if data.phone_number is not None:
        org.set_salted_phone(data.phone_number.strip())
    if data.geo_lat is not None:
        org.geo_lat = data.geo_lat
    if data.geo_lng is not None:
        org.geo_lng = data.geo_lng
    if data.registration_number is not None:
        org.registration_number = data.registration_number.strip()
    if data.headquarters_address is not None:
        org.headquarters_address = data.headquarters_address.strip()
    if data.operating_regions is not None:
        org.operating_regions = data.operating_regions.strip()
    if data.category is not None:
        org.category = data.category.strip()
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
    current_user: Account = Depends(require_role("admin", "superadmin")),
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


@router.get("/users")
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = Query(None),
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to list system users with pagination and search."""
    query = select(Account).options(joinedload(Account.user_profile))

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.join(UserProfile, Account.id == UserProfile.account_id, isouter=True).where(
            or_(
                func.lower(Account.email).like(term),
                func.lower(UserProfile.full_name).like(term),
            )
        )

    query = query.order_by(Account.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    accounts = result.scalars().all()

    items = []
    for acc in accounts:
        prof = acc.user_profile
        items.append({
            "account_id": str(acc.id),
            "email": acc.email,
            "role": acc.role.value if hasattr(acc.role, "value") else str(acc.role),
            "full_name": prof.full_name if prof else "User",
            "phone_number": prof.phone_number if prof else "",
            "blood_type": prof.blood_type if prof else None,
            "is_active": acc.is_active,
            "created_at": acc.created_at,
        })
    return items


@router.get("/emergencies")
async def list_emergencies(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = Query(None),
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to list all SOS emergencies with search, abuse detection & pagination."""
    from app.schemas.emergency import AdminEmergencyRecord
    
    query = (
        select(Emergency)
        .options(joinedload(Emergency.user), joinedload(Emergency.assigned_org))
    )

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.join(UserProfile, Emergency.user_id == UserProfile.account_id, isouter=True).where(
            or_(
                func.lower(UserProfile.full_name).like(term),
                func.lower(Emergency.type.cast(str)).like(term),
                func.lower(Emergency.status.cast(str)).like(term),
            )
        )

    query = query.order_by(Emergency.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    emergencies = result.scalars().all()

    # Pre-calculate 24h SOS counts per user for abuse detection
    twenty_four_hours_ago = datetime.now(timezone.utc) - timedelta(hours=24)
    user_ids = list(set([e.user_id for e in emergencies if e.user_id]))
    
    sos_counts = {}
    if user_ids:
        count_query = (
            select(Emergency.user_id, func.count(Emergency.id))
            .where(Emergency.user_id.in_(user_ids), Emergency.created_at >= twenty_four_hours_ago)
            .group_by(Emergency.user_id)
        )
        count_res = await db.execute(count_query)
        for uid, c in count_res.all():
            sos_counts[uid] = c

    records = []
    for e in emergencies:
        profile = e.user.user_profile if e.user else None
        phone = ""
        try:
            phone = profile.get_decrypted_phone() if profile else ""
        except Exception:
            phone = profile.phone_number if profile else ""

        u_active = e.user.is_active if e.user else True
        u_count = sos_counts.get(e.user_id, 1)
        is_abuse = u_count >= 3
        reason = f"High Frequency: {u_count} SOS alerts within 24 hours" if is_abuse else None

        records.append(
            AdminEmergencyRecord(
                emergency_id=str(e.id),
                user_id=str(e.user_id),
                user_name=profile.full_name if profile else "Unknown Citizen",
                user_phone=phone,
                user_is_active=u_active,
                blood_type=profile.blood_type or "Unknown" if profile else "Unknown",
                medical_conditions=profile.medical_conditions or "None" if profile else "None",
                type=e.type.value if hasattr(e.type, "value") else str(e.type),
                status=e.status.value if hasattr(e.status, "value") else str(e.status),
                assigned_org_name=e.assigned_org.org_name if e.assigned_org else "Unassigned",
                location_lat=e.location_lat,
                location_lng=e.location_lng,
                sos_count_24h=u_count,
                is_suspected_abuse=is_abuse,
                abuse_flag_reason=reason,
                created_at=e.created_at,
            )
        )
    return records


@router.post("/emergencies/{emergency_id}/cancel")
async def admin_cancel_emergency(
    emergency_id: str,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to forcefully cancel a fake or abusive SOS alert."""
    try:
        e_uuid = uuid_module.UUID(emergency_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid emergency ID format")

    res = await db.execute(select(Emergency).where(Emergency.id == e_uuid))
    emergency = res.scalar_one_or_none()
    if not emergency:
        raise HTTPException(status_code=404, detail="Emergency not found")

    emergency.status = EmergencyStatus.CANCELLED
    await db.commit()
    await db.refresh(emergency)

    # Purge cache
    location_cache.purge_emergency(emergency_id)

    # Broadcast cancellation
    try:
        await manager.broadcast_all({
            "event": "SOS_CANCELLED",
            "emergency_id": emergency_id,
            "reason": "Cancelled by Emergency System Administrator (False alarm / Abusive trigger)",
        })
    except Exception:
        pass

    return {"message": "Emergency cancelled successfully by admin"}


@router.post("/users/{user_id}/ban")
async def admin_ban_user(
    user_id: str,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to ban a user account and terminate all their active sessions."""
    from app.services.session_service import logout_all_user_sessions
    try:
        u_uuid = uuid_module.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user ID format")

    res = await db.execute(select(Account).where(Account.id == u_uuid))
    account = res.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="User account not found")

    if account.role in [RoleEnum.ADMIN]:
        raise HTTPException(status_code=400, detail="Cannot ban an administrator account")

    account.is_active = False
    await db.commit()

    # Terminate all active sessions immediately
    await logout_all_user_sessions(u_uuid, db)

    # Disconnect any live WebSockets
    manager.disconnect(user_id)

    return {"message": f"Account {account.email} has been banned and all active sessions revoked."}


@router.post("/users/{user_id}/unban")
async def admin_unban_user(
    user_id: str,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to unban / reactivate a user account."""
    try:
        u_uuid = uuid_module.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user ID format")

    res = await db.execute(select(Account).where(Account.id == u_uuid))
    account = res.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="User account not found")

    account.is_active = True
    await db.commit()

    return {"message": f"Account {account.email} has been reactivated successfully."}


# ── Session Monitoring & Control ──────────────────────────────────────────

@router.get("/sessions")
async def list_admin_sessions(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to monitor all active and recent user device sessions."""
    from app.services.session_service import admin_list_sessions
    return await admin_list_sessions(db=db, limit=limit)


@router.get("/sessions/user/{user_id}")
async def list_user_sessions_admin(
    user_id: str,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to inspect sessions of a specific user account."""
    from app.services.session_service import admin_list_sessions
    try:
        u_uuid = uuid_module.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    return await admin_list_sessions(db=db, user_id=u_uuid, limit=50)


@router.post("/sessions/{session_id}/terminate")
async def terminate_session_admin(
    session_id: str,
    current_user: Account = Depends(require_role("admin", "superadmin")),
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
    current_user: Account = Depends(require_role("admin", "superadmin")),
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
