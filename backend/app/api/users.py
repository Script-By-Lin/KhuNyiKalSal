"""User profile endpoints — view/update profile and real-time cache location tracking."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account
from app.models.user_profile import UserProfile
from app.core.permissions import require_role
from app.schemas.user import (
    UserProfileResponse,
    UpdateProfileRequest,
    UpdateLocationRequest,
)
from app.services.cache_service import location_cache

router = APIRouter()


@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(
    current_user: Account = Depends(require_role("user")),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    decrypted_lat, decrypted_lng = profile.get_decrypted_location()

    return UserProfileResponse(
        account_id=str(profile.account_id),
        full_name=profile.full_name,
        phone_number=profile.get_decrypted_phone(),
        blood_type=profile.blood_type,
        medical_conditions=profile.medical_conditions,
        emergency_contacts=profile.emergency_contacts,
        location_lat=decrypted_lat,
        location_lng=decrypted_lng,
    )


@router.put("/profile", response_model=UserProfileResponse)
async def update_profile(
    data: UpdateProfileRequest,
    current_user: Account = Depends(require_role("user")),
    db: AsyncSession = Depends(get_db),
):
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
        setattr(profile, field, value)

    await db.commit()
    await db.refresh(profile)

    decrypted_lat, decrypted_lng = profile.get_decrypted_location()

    return UserProfileResponse(
        account_id=str(profile.account_id),
        full_name=profile.full_name,
        phone_number=profile.get_decrypted_phone(),
        blood_type=profile.blood_type,
        medical_conditions=profile.medical_conditions,
        emergency_contacts=profile.emergency_contacts,
        location_lat=decrypted_lat,
        location_lng=decrypted_lng,
    )


@router.put("/location")
async def update_location(
    data: UpdateLocationRequest,
    current_user: Account = Depends(require_role("user")),
    db: AsyncSession = Depends(get_db),
):
    """
    Real-time location updates are stored strictly in high-speed EPHEMERAL CACHE with TTL.
    Continuous tracking is NOT committed to database disk storage for privacy and performance.
    """
    user_id = str(current_user.id)
    location_cache.set_realtime_location(
        entity_id=user_id,
        emergency_id="live",
        lat=data.lat,
        lng=data.lng,
        role="user",
        ttl_seconds=300,
    )

    result = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if profile:
        profile.set_salted_location(data.lat, data.lng)
        await db.commit()

    return {"message": "Real-time location updated in cache"}
