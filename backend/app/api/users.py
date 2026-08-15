import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account, RoleEnum
from app.models.user_profile import UserProfile
from app.models.organization import Organization
from app.models.volunteer import Volunteer
from app.core.permissions import require_role
from app.core.security import get_current_user, get_current_session_id
from app.schemas.user import (
    UserProfileResponse,
    UpdateProfileRequest,
    UpdateLocationRequest,
    DeviceTokenRequest,
)
from app.services.cache_service import location_cache

router = APIRouter()


@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    role_str = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    role_upper = role_str.upper()

    if role_upper == "ORGANIZATION":
        res = await db.execute(
            select(Organization).where(Organization.account_id == current_user.id)
        )
        org = res.scalar_one_or_none()
        if not org:
            raise HTTPException(status_code=404, detail="Organization profile not found")

        phone = ""
        try:
            phone = org.get_decrypted_phone()
        except Exception:
            phone = org.phone_number or ""

        return UserProfileResponse(
            account_id=str(org.account_id),
            role=role_upper,
            email=current_user.email,
            full_name=org.org_name,
            org_name=org.org_name,
            phone_number=phone,
            category=org.category,
            operating_regions=org.operating_regions,
            headquarters_address=org.headquarters_address,
            registration_number=org.registration_number,
            coverage_radius_km=org.coverage_radius_km,
            location_lat=org.geo_lat,
            location_lng=org.geo_lng,
        )

    elif role_upper == "VOLUNTEER":
        res = await db.execute(
            select(Volunteer).where(Volunteer.account_id == current_user.id)
        )
        vol = res.scalar_one_or_none()
        if not vol:
            raise HTTPException(status_code=404, detail="Volunteer profile not found")

        phone = ""
        try:
            phone = vol.get_decrypted_phone()
        except Exception:
            phone = vol.phone_number or ""

        return UserProfileResponse(
            account_id=str(vol.account_id),
            role=role_upper,
            email=current_user.email,
            full_name=vol.full_name,
            phone_number=phone,
            nrc_number=vol.nrc_number,
            assigned_region=vol.assigned_region,
            is_active=vol.is_active,
            location_lat=vol.current_lat,
            location_lng=vol.current_lng,
        )

    elif role_upper in ["ADMIN", "SUPERADMIN"]:
        return UserProfileResponse(
            account_id=str(current_user.id),
            role=role_upper,
            email=current_user.email,
            full_name="System Administrator",
            phone_number="",
        )

    # Standard Citizen / User Profile
    result = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    decrypted_lat, decrypted_lng = profile.get_decrypted_location()
    phone = ""
    try:
        phone = profile.get_decrypted_phone()
    except Exception:
        phone = profile.phone_number or ""

    return UserProfileResponse(
        account_id=str(profile.account_id),
        role=role_upper,
        email=current_user.email,
        full_name=profile.full_name,
        phone_number=phone,
        blood_type=profile.blood_type,
        medical_conditions=profile.medical_conditions,
        emergency_contacts=profile.emergency_contacts,
        location_lat=decrypted_lat,
        location_lng=decrypted_lng,
    )


@router.put("/profile", response_model=UserProfileResponse)
async def update_profile(
    data: UpdateProfileRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    role_str = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    role_upper = role_str.upper()

    if role_upper == "ORGANIZATION":
        res = await db.execute(
            select(Organization).where(Organization.account_id == current_user.id)
        )
        org = res.scalar_one_or_none()
        if not org:
            raise HTTPException(status_code=404, detail="Organization profile not found")

        if data.org_name or data.full_name:
            org.org_name = data.org_name or data.full_name or org.org_name
        if data.phone_number:
            org.set_salted_phone(data.phone_number)
        if data.category:
            org.category = data.category
        if data.operating_regions:
            org.operating_regions = data.operating_regions
        if data.headquarters_address:
            org.headquarters_address = data.headquarters_address
        if data.registration_number:
            org.registration_number = data.registration_number
        if data.coverage_radius_km is not None:
            org.coverage_radius_km = data.coverage_radius_km
        if data.location_lat is not None and data.location_lng is not None:
            org.geo_lat = data.location_lat
            org.geo_lng = data.location_lng

        await db.commit()
        await db.refresh(org)

        phone = ""
        try:
            phone = org.get_decrypted_phone()
        except Exception:
            phone = org.phone_number or ""

        return UserProfileResponse(
            account_id=str(org.account_id),
            role=role_upper,
            email=current_user.email,
            full_name=org.org_name,
            org_name=org.org_name,
            phone_number=phone,
            category=org.category,
            operating_regions=org.operating_regions,
            headquarters_address=org.headquarters_address,
            registration_number=org.registration_number,
            coverage_radius_km=org.coverage_radius_km,
            location_lat=org.geo_lat,
            location_lng=org.geo_lng,
        )

    elif role_upper == "VOLUNTEER":
        res = await db.execute(
            select(Volunteer).where(Volunteer.account_id == current_user.id)
        )
        vol = res.scalar_one_or_none()
        if not vol:
            raise HTTPException(status_code=404, detail="Volunteer profile not found")

        if data.full_name:
            vol.full_name = data.full_name
        if data.phone_number:
            vol.set_salted_phone(data.phone_number)
        if data.nrc_number:
            vol.nrc_number = data.nrc_number
        if data.assigned_region:
            vol.assigned_region = data.assigned_region
        if data.emergency_contact:
            vol.emergency_contact = data.emergency_contact

        await db.commit()
        await db.refresh(vol)

        phone = ""
        try:
            phone = vol.get_decrypted_phone()
        except Exception:
            phone = vol.phone_number or ""

        return UserProfileResponse(
            account_id=str(vol.account_id),
            role=role_upper,
            email=current_user.email,
            full_name=vol.full_name,
            phone_number=phone,
            nrc_number=vol.nrc_number,
            assigned_region=vol.assigned_region,
            is_active=vol.is_active,
            location_lat=vol.current_lat,
            location_lng=vol.current_lng,
        )

    # Standard Citizen / User Profile
    result = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    update_dict = data.model_dump(exclude_unset=True)
    if "phone_number" in update_dict and update_dict["phone_number"]:
        profile.set_salted_phone(update_dict.pop("phone_number"))

    for field, value in update_dict.items():
        if hasattr(profile, field):
            setattr(profile, field, value)

    await db.commit()
    await db.refresh(profile)

    decrypted_lat, decrypted_lng = profile.get_decrypted_location()
    phone = ""
    try:
        phone = profile.get_decrypted_phone()
    except Exception:
        phone = profile.phone_number or ""

    return UserProfileResponse(
        account_id=str(profile.account_id),
        role=role_upper,
        email=current_user.email,
        full_name=profile.full_name,
        phone_number=phone,
        blood_type=profile.blood_type,
        medical_conditions=profile.medical_conditions,
        emergency_contacts=profile.emergency_contacts,
        location_lat=decrypted_lat,
        location_lng=decrypted_lng,
    )


@router.put("/location")
async def update_location(
    data: UpdateLocationRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Real-time location updates are stored strictly in high-speed EPHEMERAL CACHE with TTL.
    Continuous tracking is NOT committed to database disk storage for privacy and performance.
    """
    user_id = str(current_user.id)
    role_str = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    
    location_cache.set_realtime_location(
        entity_id=user_id,
        emergency_id="live",
        lat=data.lat,
        lng=data.lng,
        role=role_str.lower(),
        ttl_seconds=300,
    )

    if role_str.upper() == "ORGANIZATION":
        org_res = await db.execute(select(Organization).where(Organization.account_id == current_user.id))
        org = org_res.scalar_one_or_none()
        if org:
            org.geo_lat = data.lat
            org.geo_lng = data.lng
            await db.commit()
    elif role_str.upper() == "VOLUNTEER":
        vol_res = await db.execute(select(Volunteer).where(Volunteer.account_id == current_user.id))
        vol = vol_res.scalar_one_or_none()
        if vol:
            vol.current_lat = data.lat
            vol.current_lng = data.lng
            await db.commit()
    else:
        result = await db.execute(
            select(UserProfile).where(UserProfile.account_id == current_user.id)
        )
        profile = result.scalar_one_or_none()
        if profile:
            profile.set_salted_location(data.lat, data.lng)
            await db.commit()

    return {"message": "Real-time location updated successfully"}


@router.get("/sessions")
async def get_user_sessions_alias(
    current_user: Account = Depends(get_current_user),
    current_session_id: Optional[uuid.UUID] = Depends(get_current_session_id),
    db: AsyncSession = Depends(get_db),
):
    """User sessions endpoint alias."""
    from app.services.session_service import list_user_sessions
    return await list_user_sessions(current_user.id, current_session_id, db)


@router.post("/device-token")
async def register_device_token(
    data: DeviceTokenRequest,
    current_user: Account = Depends(get_current_user),
    current_session_id: Optional[uuid.UUID] = Depends(get_current_session_id),
    db: AsyncSession = Depends(get_db),
):
    """Register or update device FCM token on active session for high-priority emergency push notifications."""
    from app.models.session import UserSession
    from sqlalchemy import update

    if current_session_id:
        await db.execute(
            update(UserSession)
            .where(UserSession.id == current_session_id)
            .values(fcm_token=data.fcm_token)
        )
        await db.commit()
    else:
        # Update latest active session for this user
        subq = (
            select(UserSession)
            .where(UserSession.user_id == current_user.id, UserSession.is_active == True)  # noqa: E712
            .order_by(UserSession.last_used_at.desc())
            .limit(1)
        )
        sess = (await db.execute(subq)).scalar_one_or_none()
        if sess:
            sess.fcm_token = data.fcm_token
            await db.commit()

    return {"message": "Device push token registered successfully", "status": "ok"}

