"""Blood donation API endpoints — user donation pledges, organization appointments, history."""

import uuid as uuid_module
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account
from app.models.blood_donation import BloodDonation
from app.models.organization import Organization
from app.core.security import get_current_user
from app.core.permissions import require_role
from app.schemas.blood_donation import (
    BloodDonationCreate,
    BloodDonationResponse,
    BloodDonationAccept,
    BloodDonationStatusUpdate,
)
from app.websocket.manager import manager

router = APIRouter()


def _to_response(d: BloodDonation) -> BloodDonationResponse:
    org_name = None
    org_phone = None
    if d.target_org:
        org_name = d.target_org.org_name
        org_phone = d.target_org.get_decrypted_phone()

    return BloodDonationResponse(
        id=str(d.id),
        user_id=str(d.user_id),
        donor_name=d.donor_name,
        donor_phone=d.get_decrypted_phone(),
        blood_type=d.blood_type,
        age=d.age,
        gender=d.gender,
        medical_notes=d.medical_notes,
        target_org_id=str(d.target_org_id) if d.target_org_id else None,
        target_org_name=org_name,
        target_org_phone=org_phone,
        target_location_name=d.target_location_name,
        target_lat=d.target_lat,
        target_lng=d.target_lng,
        preferred_date=d.preferred_date,
        units=d.units,
        status=d.status,
        appointment_date=d.appointment_date,
        appointment_location=d.appointment_location,
        appointment_notes=d.appointment_notes,
        notes=d.notes,
        created_at=d.created_at,
        updated_at=d.updated_at,
    )


@router.post("", response_model=BloodDonationResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=BloodDonationResponse, status_code=status.HTTP_201_CREATED)
async def create_blood_donation(
    data: BloodDonationCreate,
    current_user: Account = Depends(require_role("user", "volunteer", "organization", "admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new blood donation pledge/request.
    Pre-filled user info is submitted with this form and does NOT mutate user's main profile.
    """
    target_org_uuid = None
    if data.target_org_id:
        try:
            target_org_uuid = uuid_module.UUID(data.target_org_id)
        except ValueError:
            target_org_uuid = None

    donation = BloodDonation(
        user_id=current_user.id,
        donor_name=data.donor_name.strip(),
        donor_phone=data.donor_phone.strip(),
        blood_type=data.blood_type.strip(),
        age=data.age,
        gender=data.gender,
        medical_notes=data.medical_notes.strip() if data.medical_notes else None,
        target_org_id=target_org_uuid,
        target_location_name=data.target_location_name.strip(),
        target_lat=data.target_lat,
        target_lng=data.target_lng,
        preferred_date=data.preferred_date,
        units=data.units,
        status="Pending",
        notes=data.notes.strip() if data.notes else None,
    )
    donation.set_salted_phone(data.donor_phone.strip())

    db.add(donation)
    await db.commit()
    await db.refresh(donation)

    # If an organization is targeted, notify them via WebSocket
    if target_org_uuid:
        await manager.send_personal(str(target_org_uuid), {
            "event": "NEW_BLOOD_DONATION_REQUEST",
            "donation_id": str(donation.id),
            "donor_name": donation.donor_name,
            "blood_type": donation.blood_type,
            "preferred_date": donation.preferred_date,
            "units": donation.units,
        })

    return _to_response(donation)


@router.get("/my", response_model=list[BloodDonationResponse])
async def get_my_blood_donations(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return all blood donation pledges submitted by the current user."""
    result = await db.execute(
        select(BloodDonation)
        .where(BloodDonation.user_id == current_user.id)
        .order_by(BloodDonation.created_at.desc())
    )
    donations = result.scalars().all()
    return [_to_response(d) for d in donations]


@router.get("/org", response_model=list[BloodDonationResponse])
async def get_org_blood_donations(
    current_user: Account = Depends(require_role("organization", "admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Return blood donation requests targeted to current organization or unassigned."""
    result = await db.execute(
        select(BloodDonation)
        .where(
            (BloodDonation.target_org_id == current_user.id) | (BloodDonation.target_org_id.is_(None))
        )
        .order_by(BloodDonation.created_at.desc())
    )
    donations = result.scalars().all()
    return [_to_response(d) for d in donations]


@router.get("/all", response_model=list[BloodDonationResponse])
async def get_all_blood_donations(
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to list all blood donations."""
    result = await db.execute(
        select(BloodDonation).order_by(BloodDonation.created_at.desc())
    )
    donations = result.scalars().all()
    return [_to_response(d) for d in donations]


@router.put("/{donation_id}/accept", response_model=BloodDonationResponse)
async def accept_blood_donation_appointment(
    donation_id: str,
    data: BloodDonationAccept,
    current_user: Account = Depends(require_role("organization", "admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """
    Organization accepts blood donation request and schedules appointment with date & location.
    """
    try:
        d_uuid = uuid_module.UUID(donation_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid donation ID format")

    result = await db.execute(select(BloodDonation).where(BloodDonation.id == d_uuid))
    donation = result.scalar_one_or_none()
    if not donation:
        raise HTTPException(status_code=404, detail="Blood donation record not found")

    donation.status = "Accepted"
    donation.target_org_id = current_user.id
    donation.appointment_date = data.appointment_date.strip()
    donation.appointment_location = data.appointment_location.strip()
    if data.appointment_notes:
        donation.appointment_notes = data.appointment_notes.strip()

    await db.commit()
    await db.refresh(donation)

    # Fetch Org details for notification
    org_res = await db.execute(select(Organization).where(Organization.account_id == current_user.id))
    org_obj = org_res.scalar_one_or_none()
    org_name = org_obj.org_name if org_obj else "Rescue Medical Center"

    # Notify donor in real-time
    await manager.send_personal(str(donation.user_id), {
        "event": "BLOOD_DONATION_ACCEPTED",
        "donation_id": str(donation.id),
        "org_name": org_name,
        "appointment_date": donation.appointment_date,
        "appointment_location": donation.appointment_location,
        "appointment_notes": donation.appointment_notes,
    })

    return _to_response(donation)


@router.put("/{donation_id}/status", response_model=BloodDonationResponse)
async def update_blood_donation_status(
    donation_id: str,
    data: BloodDonationStatusUpdate,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update status of a blood donation pledge (Completed, Cancelled)."""
    try:
        d_uuid = uuid_module.UUID(donation_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid donation ID format")

    result = await db.execute(select(BloodDonation).where(BloodDonation.id == d_uuid))
    donation = result.scalar_one_or_none()
    if not donation:
        raise HTTPException(status_code=404, detail="Blood donation record not found")

    # Allow if owner or org/admin
    if donation.user_id != current_user.id and current_user.role not in ["organization", "admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Not authorized to update this donation")

    valid_statuses = ["Pending", "Accepted", "Completed", "Cancelled"]
    if data.status not in valid_statuses:
        raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {valid_statuses}")

    donation.status = data.status
    await db.commit()
    await db.refresh(donation)

    return _to_response(donation)
