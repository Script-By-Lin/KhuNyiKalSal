"""Blood donation API endpoints — user donation pledges, emergency blood requests, organization appointments, history."""

import uuid as uuid_module
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update, or_, func
from sqlalchemy.orm import selectinload
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
from app.services.location_service import find_nearest_organizations

logger = logging.getLogger(__name__)
router = APIRouter()


def _to_response(d: BloodDonation) -> BloodDonationResponse:
    org_name = None
    org_phone = None
    if d.target_org:
        org_name = d.target_org.org_name
        org_phone = d.target_org.get_decrypted_phone()

    accepted_org_name = None
    accepted_org_phone = None
    if d.accepted_org:
        accepted_org_name = d.accepted_org.org_name
        accepted_org_phone = d.accepted_org.get_decrypted_phone()

    return BloodDonationResponse(
        id=str(d.id),
        user_id=str(d.user_id),
        request_type=d.request_type or "donate",
        patient_name=d.patient_name,
        hospital_name=d.hospital_name,
        urgency_level=d.urgency_level or "Normal",
        donor_name=d.donor_name,
        donor_phone=d.get_decrypted_phone(),
        blood_type=d.blood_type,
        age=d.age,
        gender=d.gender,
        medical_notes=d.medical_notes,
        target_org_id=str(d.target_org_id) if d.target_org_id else None,
        target_org_name=org_name,
        target_org_phone=org_phone,
        accepted_org_id=str(d.accepted_org_id) if d.accepted_org_id else None,
        accepted_org_name=accepted_org_name,
        accepted_org_phone=accepted_org_phone,
        target_location_name=d.target_location_name,
        target_lat=d.target_lat,
        target_lng=d.target_lng,
        preferred_date=d.preferred_date,
        units=d.units,
        status=d.status,
        appointment_date=d.appointment_date,
        appointment_location=d.appointment_location,
        appointment_notes=d.appointment_notes,
        pickup_location_message=d.pickup_location_message,
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
    Create a new blood donation pledge or patient blood supply request.
    Pre-filled user info is submitted with this form and does NOT mutate user's main profile.
    If request_type == 'request', broadcasts to all nearest Medical & Local Voluntary orgs.
    """
    target_org_uuid = None
    if data.target_org_id:
        try:
            target_org_uuid = uuid_module.UUID(data.target_org_id)
        except ValueError:
            target_org_uuid = None

    req_type = data.request_type.lower().strip() if data.request_type else "donate"
    if req_type not in ["donate", "request"]:
        req_type = "donate"

    donation = BloodDonation(
        user_id=current_user.id,
        request_type=req_type,
        patient_name=data.patient_name.strip() if data.patient_name else None,
        hospital_name=data.hospital_name.strip() if data.hospital_name else None,
        urgency_level=data.urgency_level.strip() if data.urgency_level else "Normal",
        donor_name=data.donor_name.strip(),
        donor_phone=data.donor_phone.strip(),
        blood_type=data.blood_type.strip().upper(),
        age=data.age,
        gender=data.gender,
        medical_notes=data.medical_notes.strip() if data.medical_notes else None,
        target_org_id=target_org_uuid,
        target_location_name=data.target_location_name.strip(),
        target_lat=data.target_lat,
        target_lng=data.target_lng,
        preferred_date=data.preferred_date,
        units=max(1, data.units),
        status="Pending",
        notes=data.notes.strip() if data.notes else None,
    )
    donation.set_salted_phone(data.donor_phone.strip())

    db.add(donation)
    await db.commit()
    await db.refresh(donation)

    # ── Realtime Multi-Org Broadcast ─────────────────────────────────────────
    lat = data.target_lat or 16.8661
    lng = data.target_lng or 96.1951

    if req_type == "request":
        # Broadcast to all nearest Medical and Local Voluntary Organizations
        nearest_orgs = await find_nearest_organizations(lat, lng, db, emergency_type="medical")
        notified_ids = set()
        org_account_ids = []

        alert_payload = {
            "event": "NEW_BLOOD_SUPPLY_REQUEST",
            "donation_id": str(donation.id),
            "request_type": "request",
            "patient_name": donation.patient_name or donation.donor_name,
            "blood_type": donation.blood_type,
            "units": donation.units,
            "hospital_name": donation.hospital_name or donation.target_location_name,
            "urgency_level": donation.urgency_level,
            "contact_name": donation.donor_name,
            "contact_phone": donation.get_decrypted_phone(),
            "notes": donation.notes or donation.medical_notes,
            "location": {"lat": lat, "lng": lng},
        }

        for org_tuple in nearest_orgs:
            org_obj = org_tuple[0]
            oid_str = str(org_obj.account_id)
            await manager.send_personal(oid_str, alert_payload)
            notified_ids.add(oid_str)
            org_account_ids.append(org_obj.account_id)

        # Dispatch Push Notifications to organization staff
        if org_account_ids:
            try:
                from app.services.push_service import get_user_device_tokens, send_emergency_push
                tokens = await get_user_device_tokens(org_account_ids, db)
                if tokens:
                    await send_emergency_push(
                        tokens=tokens,
                        title=f"🚨 URGENT: {donation.blood_type} Blood Request ({donation.units} Units)",
                        body=f"Patient at {donation.hospital_name or donation.target_location_name}. Urgency: {donation.urgency_level}. Tap to fulfill/accept.",
                        data=alert_payload,
                    )
            except Exception as e:
                logger.error(f"Failed to send blood push: {e}")

    else:
        # Blood Donation Pledge
        if target_org_uuid:
            await manager.send_personal(str(target_org_uuid), {
                "event": "NEW_BLOOD_DONATION_REQUEST",
                "donation_id": str(donation.id),
                "request_type": "donate",
                "donor_name": donation.donor_name,
                "blood_type": donation.blood_type,
                "preferred_date": donation.preferred_date,
                "units": donation.units,
            })
        else:
            nearest_orgs = await find_nearest_organizations(lat, lng, db, emergency_type="medical")
            for org_tuple in nearest_orgs[:5]:
                org_obj = org_tuple[0]
                await manager.send_personal(str(org_obj.account_id), {
                    "event": "NEW_BLOOD_DONATION_REQUEST",
                    "donation_id": str(donation.id),
                    "request_type": "donate",
                    "donor_name": donation.donor_name,
                    "blood_type": donation.blood_type,
                    "preferred_date": donation.preferred_date,
                    "units": donation.units,
                })

    return _to_response(donation)


@router.get("/my", response_model=list[BloodDonationResponse])
async def get_my_blood_donations(
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return all blood donations & blood supply requests submitted by the current user with pagination & search."""
    query = (
        select(BloodDonation)
        .options(selectinload(BloodDonation.target_org), selectinload(BloodDonation.accepted_org))
        .where(BloodDonation.user_id == current_user.id)
    )

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.where(
            or_(
                func.lower(BloodDonation.patient_name).like(term),
                func.lower(BloodDonation.donor_name).like(term),
                func.lower(BloodDonation.blood_type).like(term),
                func.lower(BloodDonation.status).like(term),
                func.lower(BloodDonation.hospital_name).like(term),
            )
        )

    query = query.order_by(BloodDonation.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    donations = result.scalars().all()
    return [_to_response(d) for d in donations]


@router.get("/org", response_model=list[BloodDonationResponse])
async def get_org_blood_donations(
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
    current_user: Account = Depends(require_role("organization", "admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Return incoming blood donation pledges and blood supply requests for the organization with pagination & search."""
    query = (
        select(BloodDonation)
        .options(selectinload(BloodDonation.target_org), selectinload(BloodDonation.accepted_org))
        .where(
            or_(
                BloodDonation.target_org_id == current_user.id,
                BloodDonation.accepted_org_id == current_user.id,
                BloodDonation.target_org_id.is_(None),
                BloodDonation.request_type == "request",
            )
        )
    )

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.where(
            or_(
                func.lower(BloodDonation.patient_name).like(term),
                func.lower(BloodDonation.donor_name).like(term),
                func.lower(BloodDonation.blood_type).like(term),
                func.lower(BloodDonation.status).like(term),
                func.lower(BloodDonation.hospital_name).like(term),
            )
        )

    query = query.order_by(BloodDonation.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    donations = result.scalars().all()
    return [_to_response(d) for d in donations]


@router.get("/all", response_model=list[BloodDonationResponse])
async def get_all_blood_donations(
    skip: int = 0,
    limit: int = 100,
    search: Optional[str] = None,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to list all blood records with pagination & search."""
    query = (
        select(BloodDonation)
        .options(selectinload(BloodDonation.target_org), selectinload(BloodDonation.accepted_org))
    )

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.where(
            or_(
                func.lower(BloodDonation.patient_name).like(term),
                func.lower(BloodDonation.donor_name).like(term),
                func.lower(BloodDonation.blood_type).like(term),
                func.lower(BloodDonation.status).like(term),
            )
        )

    query = query.order_by(BloodDonation.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
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
    Organization accepts blood donation request or fulfills patient blood request.
    Specifies appointment schedule or pickup room message.
    """
    try:
        d_uuid = uuid_module.UUID(donation_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid donation ID format")

    result = await db.execute(
        select(BloodDonation)
        .options(selectinload(BloodDonation.target_org), selectinload(BloodDonation.accepted_org))
        .where(BloodDonation.id == d_uuid)
    )
    donation = result.scalar_one_or_none()
    if not donation:
        raise HTTPException(status_code=404, detail="Blood donation record not found")

    donation.status = "Accepted"
    donation.accepted_org_id = current_user.id
    if not donation.target_org_id:
        donation.target_org_id = current_user.id

    if data.appointment_date:
        donation.appointment_date = data.appointment_date.strip()
    if data.appointment_location:
        donation.appointment_location = data.appointment_location.strip()
    if data.appointment_notes:
        donation.appointment_notes = data.appointment_notes.strip()
    if data.pickup_location_message:
        donation.pickup_location_message = data.pickup_location_message.strip()

    await db.commit()
    await db.refresh(donation)

    # Fetch Org details for notification
    org_res = await db.execute(select(Organization).where(Organization.account_id == current_user.id))
    org_obj = org_res.scalar_one_or_none()
    org_name = org_obj.org_name if org_obj else "Rescue Medical Center"
    org_phone = org_obj.get_decrypted_phone() if org_obj else ""

    # Real-time WebSocket notification to the user / requester
    await manager.send_personal(str(donation.user_id), {
        "event": "BLOOD_REQUEST_ACCEPTED",
        "donation_id": str(donation.id),
        "request_type": donation.request_type or "donate",
        "status": "Accepted",
        "org_name": org_name,
        "org_phone": org_phone,
        "appointment_date": donation.appointment_date,
        "appointment_location": donation.appointment_location,
        "appointment_notes": donation.appointment_notes,
        "pickup_location_message": donation.pickup_location_message or donation.appointment_location,
    })

    # Also push notification to user's device
    try:
        from app.services.push_service import get_user_device_tokens, send_emergency_push
        user_tokens = await get_user_device_tokens([donation.user_id], db)
        if user_tokens:
            is_req = (donation.request_type == "request")
            title = f"✅ Blood Request FULFILLED by {org_name}" if is_req else f"✅ Blood Donation Appointment Confirmed by {org_name}"
            msg = donation.pickup_location_message or donation.appointment_location or "Ready for pickup."
            await send_emergency_push(
                tokens=user_tokens,
                title=title,
                body=f"Location: {msg}. Date: {donation.appointment_date or 'Immediate'}",
                data={
                    "event": "BLOOD_REQUEST_ACCEPTED",
                    "donation_id": str(donation.id),
                },
            )
    except Exception as e:
        logger.error(f"Failed to send push to donor/requester: {e}")

    return _to_response(donation)


@router.put("/{donation_id}/status", response_model=BloodDonationResponse)
async def update_blood_donation_status(
    donation_id: str,
    data: BloodDonationStatusUpdate,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update status of a blood donation / supply request (Completed, Cancelled)."""
    try:
        d_uuid = uuid_module.UUID(donation_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid donation ID format")

    result = await db.execute(
        select(BloodDonation)
        .options(selectinload(BloodDonation.target_org), selectinload(BloodDonation.accepted_org))
        .where(BloodDonation.id == d_uuid)
    )
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

    # Real-time WebSocket broadcast to relevant parties
    if data.status == "Cancelled":
        if donation.accepted_org_id:
            await manager.send_personal(str(donation.accepted_org_id), {
                "event": "BLOOD_REQUEST_CANCELLED",
                "donation_id": str(donation.id),
                "request_type": donation.request_type or "donate",
                "status": "Cancelled",
            })
        if donation.target_org_id and donation.target_org_id != donation.accepted_org_id:
            await manager.send_personal(str(donation.target_org_id), {
                "event": "BLOOD_REQUEST_CANCELLED",
                "donation_id": str(donation.id),
                "request_type": donation.request_type or "donate",
                "status": "Cancelled",
            })
        await manager.broadcast({
            "event": "BLOOD_REQUEST_CANCELLED",
            "donation_id": str(donation.id),
            "request_type": donation.request_type or "donate",
            "status": "Cancelled",
        })

    return _to_response(donation)
