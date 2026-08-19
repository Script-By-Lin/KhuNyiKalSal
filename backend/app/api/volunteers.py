"""Volunteer endpoints — CRUD, status toggle, emergency response, real-time cache location tracking, alerts."""

import uuid as uuid_module

from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, or_, func
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
    AssignVolunteerRequest,
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

        vol_name = None
        vol_loc = None
        if e.assigned_volunteer_id:
            if e.assigned_volunteer:
                vol_name = e.assigned_volunteer.full_name
                if e.assigned_volunteer.current_lat and e.assigned_volunteer.current_lng:
                    vol_loc = {"lat": e.assigned_volunteer.current_lat, "lng": e.assigned_volunteer.current_lng}
            else:
                v_res = await db.execute(select(Volunteer).where(Volunteer.account_id == e.assigned_volunteer_id))
                vol_obj = v_res.scalar_one_or_none()
                if vol_obj:
                    vol_name = vol_obj.full_name
                    if vol_obj.current_lat and vol_obj.current_lng:
                        vol_loc = {"lat": vol_obj.current_lat, "lng": vol_obj.current_lng}

        alerts.append({
            "event": "SOS_CREATED",
            "emergency_id": e_id,
            "id": e_id,
            "type": e.type.value,
            "location": {"lat": e.location_lat, "lng": e.location_lng},
            "org_location": org_loc,
            "assigned_org_id": str(e.assigned_org_id) if e.assigned_org_id else None,
            "assigned_volunteer_id": str(e.assigned_volunteer_id) if e.assigned_volunteer_id else None,
            "assigned_volunteer_name": vol_name,
            "assigned_volunteer_location": vol_loc,
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
    skip: int = 0,
    limit: Optional[int] = None,
    search: Optional[str] = None,
    current_user: Account = Depends(require_role("organization", "volunteer")),
    db: AsyncSession = Depends(get_db),
):
    """Fetch completed and cancelled emergency history specifically for the responder's own organization with pagination & search."""
    role_str = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    role_upper = role_str.upper()

    if role_upper == "ORGANIZATION":
        v_sub = select(Volunteer.account_id).where(Volunteer.org_id == current_user.id)
        query = select(Emergency).where(
            or_(
                Emergency.assigned_org_id == current_user.id,
                Emergency.assigned_volunteer_id.in_(v_sub),
            ),
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

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        from app.models.user_profile import UserProfile
        query = query.join(UserProfile, Emergency.user_id == UserProfile.account_id, isouter=True).where(
            or_(
                func.lower(UserProfile.full_name).like(term),
                func.lower(Emergency.type.cast(str)).like(term),
                func.lower(Emergency.status.cast(str)).like(term),
            )
        )

    query = query.order_by(Emergency.created_at.desc()).offset(skip)
    if limit is not None and limit > 0:
        query = query.limit(limit)

    result = await db.execute(query)
    emergencies = result.scalars().all()

    records = []
    for e in emergencies:
        profile = e.user.user_profile if e.user else None

        records.append({
            "emergency_id": str(e.id),
            "type": e.type.value if hasattr(e.type, "value") else str(e.type),
            "status": e.status.value if hasattr(e.status, "value") else str(e.status),
            "location": {"lat": e.location_lat, "lng": e.location_lng},
            "user_info": {
                "full_name": profile.full_name if profile else "Unknown User",
                "phone_number": profile.get_decrypted_phone() if profile else "",
                "blood_type": profile.blood_type or "Unknown",
                "medical_conditions": profile.medical_conditions or "None",
            },
            "created_at": e.created_at.isoformat() if e.created_at else None,
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


@router.post("/assign")
async def assign_volunteer_to_emergency(
    data: AssignVolunteerRequest,
    current_user: Account = Depends(require_role("organization")),
    db: AsyncSession = Depends(get_db),
):
    """Organization assigns an emergency to a specific volunteer belonging to their organization."""
    try:
        e_uuid = uuid_module.UUID(data.emergency_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid emergency_id format")

    try:
        v_uuid = uuid_module.UUID(data.volunteer_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid volunteer_id format")

    # Verify volunteer belongs to this organization
    v_res = await db.execute(
        select(Volunteer).where(Volunteer.account_id == v_uuid)
    )
    volunteer = v_res.scalar_one_or_none()
    if not volunteer:
        raise HTTPException(status_code=404, detail="Volunteer not found")

    if volunteer.org_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Volunteer does not belong to your organization"
        )

    # Verify emergency exists
    e_res = await db.execute(
        select(Emergency).where(Emergency.id == e_uuid)
    )
    emergency = e_res.scalar_one_or_none()
    if not emergency:
        raise HTTPException(status_code=404, detail="Emergency not found")

    if emergency.status not in (EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED):
        raise HTTPException(
            status_code=400, detail="Emergency is already completed or cancelled"
        )

    emergency.assigned_org_id = current_user.id
    emergency.assigned_volunteer_id = volunteer.account_id
    emergency.status = EmergencyStatus.ACCEPTED

    # Fetch organization details
    o_res = await db.execute(
        select(Organization).where(Organization.account_id == current_user.id)
    )
    org = o_res.scalar_one_or_none()
    org_name = org.org_name if org else "Rescue Organization"

    await db.commit()

    responder_lat = volunteer.current_lat or (emergency.location_lat - 0.015)
    responder_lng = volunteer.current_lng or (emergency.location_lng - 0.010)

    accept_payload = {
        "event": "VOLUNTEER_ACCEPTED",
        "emergency_id": data.emergency_id,
        "status": "accepted",
        "assigned_org_id": str(emergency.assigned_org_id),
        "assigned_volunteer_id": str(volunteer.account_id),
        "assigned_volunteer_name": volunteer.full_name,
        "volunteer_id": str(volunteer.account_id),
        "responder_name": volunteer.full_name,
        "responder_phone": volunteer.get_decrypted_phone(),
        "responder_role": "Volunteer",
        "responder_location": {"lat": responder_lat, "lng": responder_lng},
        "message": f"🚨 {volunteer.full_name} ({org_name}) has been dispatched to your location!",
    }

    # Notify victim, assigned volunteer, and organization
    await manager.send_personal(str(emergency.user_id), accept_payload)
    await manager.send_personal(str(volunteer.account_id), accept_payload)
    await manager.send_personal(str(current_user.id), accept_payload)
    await manager.broadcast_all(accept_payload)

    # Generic accepted event for standard listeners
    accept_payload_generic = dict(accept_payload)
    accept_payload_generic["event"] = "EMERGENCY_ACCEPTED"
    await manager.send_personal(str(emergency.user_id), accept_payload_generic)

    return {
        "message": f"Assigned to {volunteer.full_name} successfully",
        "emergency_id": data.emergency_id,
        "assigned_volunteer_id": str(volunteer.account_id),
        "assigned_volunteer_name": volunteer.full_name,
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
        responder_name = "Rescue Responder"
        responder_phone = ""
        responder_role = "Organization"
        responder_lat = emergency.location_lat - 0.015
        responder_lng = emergency.location_lng - 0.010

        if current_user.role == RoleEnum.VOLUNTEER:
            emergency.assigned_volunteer_id = current_user.id
            v_res = await db.execute(select(Volunteer).where(Volunteer.account_id == current_user.id))
            vol = v_res.scalar_one_or_none()
            if vol:
                emergency.assigned_org_id = vol.org_id
                responder_name = vol.full_name
                responder_phone = vol.get_decrypted_phone()
                responder_role = "Volunteer"
                if vol.current_lat and vol.current_lng:
                    responder_lat = vol.current_lat
                    responder_lng = vol.current_lng
        elif current_user.role == RoleEnum.ORGANIZATION:
            emergency.assigned_org_id = current_user.id
            o_res = await db.execute(select(Organization).where(Organization.account_id == current_user.id))
            org = o_res.scalar_one_or_none()
            if org:
                responder_name = org.org_name
                responder_phone = org.get_decrypted_phone()
                responder_role = "Organization"
                responder_lat = org.geo_lat
                responder_lng = org.geo_lng

        await db.commit()

        response_tracker.respond(data.emergency_id, str(current_user.id), True)

        accept_payload = {
            "event": "VOLUNTEER_ACCEPTED",
            "emergency_id": data.emergency_id,
            "status": "accepted",
            "assigned_org_id": str(emergency.assigned_org_id) if emergency.assigned_org_id else None,
            "assigned_volunteer_id": str(emergency.assigned_volunteer_id) if emergency.assigned_volunteer_id else None,
            "assigned_volunteer_name": responder_name,
            "volunteer_id": str(current_user.id),
            "responder_name": responder_name,
            "responder_phone": responder_phone,
            "responder_role": responder_role,
            "responder_location": {"lat": responder_lat, "lng": responder_lng},
            "message": f"🚨 {responder_name} has accepted distress call and is en route!",
        }
        await manager.send_personal(str(emergency.user_id), accept_payload)
        
        # Send to assigned organization and broadcast to active dashboard listeners
        if emergency.assigned_org_id:
            await manager.send_personal(str(emergency.assigned_org_id), accept_payload)
        await manager.broadcast_all(accept_payload)
        
        # Also send EMERGENCY_ACCEPTED event for generic event handlers
        accept_payload_generic = dict(accept_payload)
        accept_payload_generic["event"] = "EMERGENCY_ACCEPTED"
        await manager.send_personal(str(emergency.user_id), accept_payload_generic)

        return {"message": "Emergency accepted", "assigned_volunteer_name": responder_name}

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

        # If active process_sos background loop is listening, wake it up to advance immediately
        if data.emergency_id in response_tracker._events:
            response_tracker.respond(data.emergency_id, str(current_user.id), False)
            return {"message": "Emergency rejected and rerouting initiated"}

        # Fallback manual reroute if background task is not active (e.g. after server restart)
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

