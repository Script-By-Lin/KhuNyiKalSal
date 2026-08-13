"""Volunteer endpoints — CRUD, status toggle, emergency response, real-time cache location tracking, alerts."""

import uuid as uuid_module

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.organization import Organization
from app.database import get_db
from app.models.account import Account, RoleEnum
from app.models.volunteer import Volunteer
from app.models.user_profile import UserProfile
from app.models.emergency import Emergency, EmergencyStatus
from app.core.security import get_current_user, hash_password
from app.core.permissions import require_role
from app.schemas.volunteer import (
    CreateVolunteerRequest,
    VolunteerResponse,
    VolunteerRespondRequest,
    UpdateVolunteerLocationRequest,
)
from app.services.sos_service import response_tracker
from app.services.location_service import find_nearest_organizations
from app.services.cache_service import location_cache
from app.websocket.manager import manager

router = APIRouter()


@router.post("/", response_model=VolunteerResponse)
async def create_volunteer(
    data: CreateVolunteerRequest,
    current_user: Account = Depends(require_role("organization")),
    db: AsyncSession = Depends(get_db),
):
    """Organization creates a new volunteer account with salted phone number."""
    result = await db.execute(select(Account).where(Account.email == data.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    account = Account(
        email=data.email,
        hashed_password=hash_password(data.password),
        role=RoleEnum.VOLUNTEER,
    )
    db.add(account)
    await db.flush()

    volunteer = Volunteer(
        account_id=account.id,
        org_id=current_user.id,
        full_name=data.full_name,
        phone_number=data.phone_number,
        is_active=True,
    )
    volunteer.set_salted_phone(data.phone_number)
    db.add(volunteer)
    await db.commit()

    return VolunteerResponse(
        account_id=str(account.id),
        org_id=str(current_user.id),
        full_name=volunteer.full_name,
        phone_number=volunteer.get_decrypted_phone(),
        is_active=volunteer.is_active,
    )


@router.get("/", response_model=list[VolunteerResponse])
async def list_volunteers(
    current_user: Account = Depends(require_role("organization")),
    db: AsyncSession = Depends(get_db),
):
    """List all volunteers belonging to the authenticated organization."""
    result = await db.execute(
        select(Volunteer).where(Volunteer.org_id == current_user.id)
    )
    volunteers = result.scalars().all()
    return [
        VolunteerResponse(
            account_id=str(v.account_id),
            org_id=str(v.org_id),
            full_name=v.full_name,
            phone_number=v.get_decrypted_phone(),
            is_active=v.is_active,
            current_lat=v.current_lat,
            current_lng=v.current_lng,
        )
        for v in volunteers
    ]


@router.get("/alerts")
async def get_active_alerts(
    current_user: Account = Depends(require_role("organization", "volunteer")),
    db: AsyncSession = Depends(get_db),
):
    """Fetch active pending and accepted emergency alerts for volunteer or organization dashboard."""
    user_org_id = str(current_user.id)
    if current_user.role == RoleEnum.VOLUNTEER:
        v_res = await db.execute(
            select(Volunteer).where(Volunteer.account_id == current_user.id)
        )
        vol = v_res.scalar_one_or_none()
        if vol:
            user_org_id = str(vol.org_id)

    result = await db.execute(
        select(Emergency)
        .where(Emergency.status.in_([EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED]))
        .order_by(Emergency.created_at.desc())
    )
    emergencies = result.scalars().all()

    alerts = []
    for e in emergencies:
        e_id = str(e.id)

        # Skip if current user or their organization has rejected this emergency
        if response_tracker.is_rejected_by(e_id, str(current_user.id)) or response_tracker.is_rejected_by(e_id, user_org_id):
            continue

        # Show alert ONLY to the specifically assigned organization and its related volunteers
        if e.assigned_org_id and str(e.assigned_org_id) != user_org_id:
            continue

        profile = e.user.user_profile

        org_loc = None
        if e.assigned_org_id and e.assigned_org:
            org_obj = e.assigned_org
            if org_obj:
                org_loc = {"lat": org_obj.geo_lat, "lng": org_obj.geo_lng}

        alerts.append({
            "event": "SOS_CREATED",
            "emergency_id": e_id,
            "type": e.type.value,
            "location": {"lat": e.location_lat, "lng": e.location_lng},
            "org_location": org_loc,
            "user_info": {
                "full_name": profile.full_name if profile else "Unknown User",
                "phone_number": profile.get_decrypted_phone() if profile else "",
                "blood_type": profile.blood_type or "Unknown",
                "medical_conditions": profile.medical_conditions or "None",
            },
            "status": e.status.value,
            "created_at": e.created_at.isoformat(),
        })

    return alerts


@router.get("/history")
async def get_responder_history(
    current_user: Account = Depends(require_role("organization", "volunteer")),
    db: AsyncSession = Depends(get_db),
):
    """Fetch completed and cancelled emergency history specifically for the responder's own organization."""
    if current_user.role == RoleEnum.ORGANIZATION:
        query = select(Emergency).where(
            Emergency.assigned_org_id == current_user.id,
            Emergency.status.in_([EmergencyStatus.COMPLETED, EmergencyStatus.CANCELLED])
        )
    else:
        v_res = await db.execute(
            select(Volunteer).where(Volunteer.account_id == current_user.id)
        )
        vol = v_res.scalar_one_or_none()
        org_id = vol.org_id if vol else current_user.id
        query = select(Emergency).where(
            or_(
                Emergency.assigned_volunteer_id == current_user.id,
                Emergency.assigned_org_id == org_id
            ),
            Emergency.status.in_([EmergencyStatus.COMPLETED, EmergencyStatus.CANCELLED])
        )

    result = await db.execute(query.order_by(Emergency.created_at.desc()).limit(50))
    emergencies = result.scalars().all()

    records = []
    for e in emergencies:
        profile = e.user.user_profile

        records.append({
            "emergency_id": str(e.id),
            "type": e.type.value,
            "status": e.status.value,
            "location": {"lat": e.location_lat, "lng": e.location_lng},
            "user_info": {
                "full_name": profile.full_name if profile else "Unknown User",
                "phone_number": profile.get_decrypted_phone() if profile else "",
                "blood_type": profile.blood_type or "Unknown",
                "medical_conditions": profile.medical_conditions or "None",
            },
            "created_at": e.created_at.isoformat(),
            "updated_at": e.updated_at.isoformat() if e.updated_at else None,
        })

    return records


@router.put("/{volunteer_id}/toggle-status")
async def toggle_volunteer_status(
    volunteer_id: str,
    current_user: Account = Depends(require_role("organization", "volunteer")),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Volunteer).where(
            Volunteer.account_id == uuid_module.UUID(volunteer_id)
        )
    )
    volunteer = result.scalar_one_or_none()
    if not volunteer:
        raise HTTPException(status_code=404, detail="Volunteer not found")

    if (
        current_user.role.value == "organization"
        and volunteer.org_id != current_user.id
    ):
        raise HTTPException(status_code=403, detail="Not your volunteer")
    if (
        current_user.role.value == "volunteer"
        and volunteer.account_id != current_user.id
    ):
        raise HTTPException(status_code=403, detail="Not your account")

    volunteer.is_active = not volunteer.is_active
    await db.commit()
    return {
        "message": f"Volunteer is now {'active' if volunteer.is_active else 'inactive'}"
    }


@router.post("/respond")
async def respond_to_emergency(
    data: VolunteerRespondRequest,
    current_user: Account = Depends(require_role("volunteer", "organization")),
    db: AsyncSession = Depends(get_db),
):
    """Volunteer or Organization accepts or rejects an emergency alert. Rejections reroute to the next nearest organization."""
    action = data.action.lower()
    if action not in ("accept", "reject"):
        raise HTTPException(
            status_code=400, detail="Action must be 'accept' or 'reject'"
        )

    result = await db.execute(
        select(Emergency).where(
            Emergency.id == uuid_module.UUID(data.emergency_id)
        )
    )
    emergency = result.scalar_one_or_none()
    if not emergency:
        raise HTTPException(status_code=404, detail="Emergency not found")
    if emergency.status != EmergencyStatus.PENDING:
        raise HTTPException(
            status_code=400, detail="Emergency is no longer pending"
        )

    accepted = action == "accept"

    if accepted:
        emergency.status = EmergencyStatus.ACCEPTED
        if current_user.role == RoleEnum.VOLUNTEER:
            emergency.assigned_volunteer_id = current_user.id
            v_res = await db.execute(select(Volunteer).where(Volunteer.account_id == current_user.id))
            vol = v_res.scalar_one_or_none()
            if vol:
                emergency.assigned_org_id = vol.org_id
        elif current_user.role == RoleEnum.ORGANIZATION:
            emergency.assigned_org_id = current_user.id
        await db.commit()

        response_tracker.respond(data.emergency_id, str(current_user.id), True)

        await manager.send_personal(str(emergency.user_id), {
            "event": "VOLUNTEER_ACCEPTED",
            "emergency_id": data.emergency_id,
            "volunteer_id": str(current_user.id),
            "message": "Help is on the way!",
        })
        return {"message": "Emergency accepted"}

    else:
        # Rejection handling — strictly record rejection, do NOT reroute
        user_org_id = str(current_user.id)
        if current_user.role == RoleEnum.VOLUNTEER:
            v_res = await db.execute(select(Volunteer).where(Volunteer.account_id == current_user.id))
            vol = v_res.scalar_one_or_none()
            if vol:
                user_org_id = str(vol.org_id)

        response_tracker.add_rejection(data.emergency_id, str(current_user.id))
        response_tracker.add_rejection(data.emergency_id, user_org_id)

        # Reroute to next available non-rejecting organization
        org_distances = await find_nearest_organizations(
            emergency.location_lat, emergency.location_lng, db, emergency_type=emergency.type.value
        )
        rejected = response_tracker.get_rejected(data.emergency_id)

        next_org = None
        for org, dist in org_distances:
            if str(org.account_id) not in rejected:
                next_org = org
                break

        if next_org:
            emergency.assigned_org_id = next_org.account_id
            await db.commit()

            # Alert next organization
            prof_res = await db.execute(select(UserProfile).where(UserProfile.account_id == emergency.user_id))
            profile = prof_res.scalar_one_or_none()
            user_info = {
                "full_name": profile.full_name if profile else "Unknown User",
                "phone_number": profile.get_decrypted_phone() if profile else "",
                "blood_type": profile.blood_type or "Unknown",
                "medical_conditions": profile.medical_conditions or "None",
            }
            alert_payload = {
                "event": "SOS_CREATED",
                "emergency_id": data.emergency_id,
                "type": emergency.type.value,
                "location": {"lat": emergency.location_lat, "lng": emergency.location_lng},
                "user_info": user_info,
                "organization": next_org.org_name,
            }
            
            notified_uids = set()
            await manager.send_personal(str(next_org.account_id), alert_payload)
            notified_uids.add(str(next_org.account_id))

            vol_result = await db.execute(
                select(Volunteer).where(
                    Volunteer.org_id == next_org.account_id,
                    Volunteer.is_active == True,
                )
            )
            for v in vol_result.scalars().all():
                vid = str(v.account_id)
                await manager.send_personal(vid, alert_payload)
                notified_uids.add(vid)

            # Notify victim user of reroute
            await manager.send_personal(str(emergency.user_id), {
                "event": "REROUTE_TRIGGERED",
                "emergency_id": data.emergency_id,
                "message": f"Re-routing to {next_org.org_name}...",
            })
        else:
            # All organizations rejected -> cancel emergency
            emergency.status = EmergencyStatus.CANCELLED
            await db.commit()

            await manager.send_personal(str(emergency.user_id), {
                "event": "SOS_CANCELLED",
                "emergency_id": data.emergency_id,
                "message": "All nearby rescue organizations are unavailable. Please contact emergency services.",
            })

        return {"message": "Emergency rejected and rerouted if available"}


@router.put("/location")
async def update_volunteer_location(
    data: UpdateVolunteerLocationRequest,
    current_user: Account = Depends(require_role("volunteer", "organization")),
    db: AsyncSession = Depends(get_db),
):
    """
    Update live responder location strictly in EPHEMERAL CACHE with TTL.
    Broadcasts live coordinates to victim without writing continuous movement to DB disk.
    """
    responder_id = str(current_user.id)

    # Find active accepted emergencies for this responder
    em_result = await db.execute(
        select(Emergency).where(
            Emergency.status == EmergencyStatus.ACCEPTED,
        )
    )
    active_emergencies = em_result.scalars().all()
    for e in active_emergencies:
        if e.assigned_volunteer_id == current_user.id or e.assigned_org_id == current_user.id:
            # Store in Ephemeral Location Cache
            location_cache.set_realtime_location(
                entity_id=responder_id,
                emergency_id=str(e.id),
                lat=data.lat,
                lng=data.lng,
                role="responder",
                ttl_seconds=300,
            )

            # Broadcast live location over WebSocket to victim
            await manager.send_personal(str(e.user_id), {
                "event": "RESPONDER_LOCATION_UPDATED",
                "emergency_id": str(e.id),
                "location": {"lat": data.lat, "lng": data.lng},
            })

    return {"message": "Live responder location updated in cache"}
