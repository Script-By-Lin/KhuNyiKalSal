"""User profile endpoints — view/update profile and location."""

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
    return UserProfileResponse(
        account_id=str(profile.account_id),
        full_name=profile.full_name,
        phone_number=profile.phone_number,
        blood_type=profile.blood_type,
        medical_conditions=profile.medical_conditions,
        emergency_contacts=profile.emergency_contacts,
        location_lat=profile.location_lat,
        location_lng=profile.location_lng,
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

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)
    await db.commit()
    await db.refresh(profile)

    return UserProfileResponse(
        account_id=str(profile.account_id),
        full_name=profile.full_name,
        phone_number=profile.phone_number,
        blood_type=profile.blood_type,
        medical_conditions=profile.medical_conditions,
        emergency_contacts=profile.emergency_contacts,
        location_lat=profile.location_lat,
        location_lng=profile.location_lng,
    )


@router.put("/location")
async def update_location(
    data: UpdateLocationRequest,
    current_user: Account = Depends(require_role("user")),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    profile.location_lat = data.lat
    profile.location_lng = data.lng
    await db.commit()
    return {"message": "Location updated"}
