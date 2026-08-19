"""Emergency endpoints — SOS creation, status, history, completion, cancellation, real-time cache purge."""

import asyncio
import uuid as uuid_module

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from app.database import get_db
from app.models.account import Account
from app.models.emergency import Emergency, EmergencyType, EmergencyStatus
from app.models.family import FamilyAlert
from app.core.security import get_current_user, get_current_session_id
from app.core.permissions import require_role
from app.core.abuse import check_sos_limit
from app.schemas.emergency import SOSRequest, EmergencyResponse, SOSCreatedResponse
from app.services.sos_service import process_sos
from app.services.session_service import lock_emergency_session
from app.services.cache_service import location_cache
from app.websocket.manager import manager

router = APIRouter()


@router.post("/sos", response_model=SOSCreatedResponse)
async def create_sos(
    data: SOSRequest,
    current_user: Account = Depends(get_current_user),
    current_session_id: Optional[uuid_module.UUID] = Depends(get_current_session_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Trigger an SOS alert. Creates an emergency record and launches
    background processing (nearest-org search → volunteer alerting → rerouting).
    Locks the user to the current device session and deactivates other sessions.
    """
    await check_sos_limit(current_user.id, db)

    normalized_type = data.type.lower().strip().replace(" ", "_")
    if normalized_type == "disaster":
        normalized_type = "natural_disaster"

    try:
        etype = EmergencyType(normalized_type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid emergency type. Use: fire, medical, accident, natural_disaster",
        )

    emergency = Emergency(
        user_id=current_user.id,
        type=etype,
        status=EmergencyStatus.PENDING,
        location_lat=data.location_lat,
        location_lng=data.location_lng,
    )
    db.add(emergency)
    await db.commit()
    await db.refresh(emergency)

    # Lock user to current session, deactivating other active sessions
    await lock_emergency_session(current_user.id, current_session_id, db)

    # Launch the SOS flow as a background coroutine
    asyncio.create_task(
        process_sos(
            emergency_id=str(emergency.id),
            user_id=str(current_user.id),
            lat=data.location_lat,
            lng=data.location_lng,
            emergency_type=normalized_type,
        )
    )

    return SOSCreatedResponse(emergency_id=str(emergency.id))


@router.get("/active", response_model=list[EmergencyResponse])
async def get_active_emergencies(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return all pending/accepted emergencies for the current user."""
    result = await db.execute(
        select(Emergency).where(
            Emergency.user_id == current_user.id,
            Emergency.status.in_([EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED]),
        )
    )
    emergencies = result.scalars().all()
    return [_to_response(e) for e in emergencies]


@router.get("/history", response_model=list[EmergencyResponse])
async def get_emergency_history(
    skip: int = 0,
    limit: Optional[int] = None,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return emergency history for the current user with optional pagination. If limit is not set, returns all records."""
    query = (
        select(Emergency)
        .where(Emergency.user_id == current_user.id)
        .order_by(Emergency.created_at.desc())
        .offset(skip)
    )
    if limit is not None and limit > 0:
        query = query.limit(limit)

    result = await db.execute(query)
    emergencies = result.scalars().all()
    return [_to_response(e) for e in emergencies]


@router.post("/cancel-active")
async def cancel_active_emergencies(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel all active pending/accepted emergencies (used during logout). Purges real-time location cache."""
    result = await db.execute(
        select(Emergency).where(
            Emergency.user_id == current_user.id,
            Emergency.status.in_([EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED]),
        )
    )
    active_list = result.scalars().all()
    for e in active_list:
        location_cache.purge_realtime_tracking(str(e.id))
    location_cache.purge_user_tracking(str(current_user.id))

    await db.execute(
        update(Emergency)
        .where(
            Emergency.user_id == current_user.id,
            Emergency.status.in_([EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED]),
        )
        .values(status=EmergencyStatus.CANCELLED)
    )
    await db.commit()
    return {"message": "Active emergencies cancelled and real-time tracking cache purged"}


@router.get("/{emergency_id}", response_model=EmergencyResponse)
async def get_emergency(
    emergency_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Emergency).where(
            Emergency.id == uuid_module.UUID(emergency_id)
        )
    )
    emergency = result.scalar_one_or_none()
    if not emergency:
        raise HTTPException(status_code=404, detail="Emergency not found")
    return _to_response(emergency)


@router.put("/{emergency_id}/complete")
async def complete_emergency(
    emergency_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark an emergency as completed, notify victim/responders via WebSocket, and purge real-time tracking cache."""
    emergency = None
    try:
        e_uuid = uuid_module.UUID(emergency_id)
        result = await db.execute(
            select(Emergency).where(Emergency.id == e_uuid)
        )
        emergency = result.scalar_one_or_none()
    except Exception:
        pass

    if not emergency:
        # Fallback: get the most recent active emergency if matching ID fails
        res2 = await db.execute(
            select(Emergency).where(
                Emergency.status.in_([EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED])
            ).order_by(Emergency.created_at.desc())
        )
        emergency = res2.scalars().first()

    if not emergency:
        raise HTTPException(status_code=404, detail="No active emergency found to complete")

    emergency.status = EmergencyStatus.COMPLETED
    
    role_str = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    if role_str.upper() == "ORGANIZATION" and not emergency.assigned_org_id:
        emergency.assigned_org_id = current_user.id
    elif role_str.upper() == "VOLUNTEER" and not emergency.assigned_volunteer_id:
        emergency.assigned_volunteer_id = current_user.id

    # Mark associated family alerts as resolved
    await db.execute(
        update(FamilyAlert)
        .where(FamilyAlert.emergency_id == emergency.id)
        .values(is_resolved=True)
    )
    
    await db.commit()

    # Instantly purge real-time tracking cache for fast & secure data removal
    location_cache.purge_realtime_tracking(str(emergency.id))
    location_cache.purge_user_tracking(str(emergency.user_id))

    # Notify victim and responders via WebSocket
    payload = {
        "event": "EMERGENCY_COMPLETED",
        "emergency_id": str(emergency.id),
        "message": "Emergency rescue completed successfully!",
    }
    await manager.send_personal(str(emergency.user_id), payload)
    if emergency.assigned_org_id:
        await manager.send_personal(str(emergency.assigned_org_id), payload)
    if emergency.assigned_volunteer_id:
        await manager.send_personal(str(emergency.assigned_volunteer_id), payload)

    return {"message": "Emergency marked as completed and tracking cache purged"}


@router.put("/{emergency_id}/cancel")
async def cancel_emergency_by_id(
    emergency_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel a specific emergency call by user and purge real-time tracking cache."""
    emergency = None
    try:
        e_uuid = uuid_module.UUID(emergency_id)
        result = await db.execute(
            select(Emergency).where(Emergency.id == e_uuid)
        )
        emergency = result.scalar_one_or_none()
    except Exception:
        pass

    if not emergency:
        res2 = await db.execute(
            select(Emergency).where(
                Emergency.user_id == current_user.id,
                Emergency.status.in_([EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED])
            ).order_by(Emergency.created_at.desc())
        )
        emergency = res2.scalars().first()

    if not emergency:
        raise HTTPException(status_code=404, detail="No active emergency found to cancel")

    user_role_str = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    if (
        emergency.status == EmergencyStatus.ACCEPTED
        and emergency.user_id == current_user.id
        and user_role_str.lower() not in ["organization", "volunteer", "admin", "superadmin"]
    ):
        raise HTTPException(
            status_code=400,
            detail="Cannot cancel emergency after a rescue team has already accepted. Please contact the rescue team directly.",
        )

    emergency.status = EmergencyStatus.CANCELLED
    
    # Mark associated family alerts as resolved
    await db.execute(
        update(FamilyAlert)
        .where(FamilyAlert.emergency_id == emergency.id)
        .values(is_resolved=True)
    )
    
    await db.commit()

    # Instantly purge real-time tracking cache
    location_cache.purge_realtime_tracking(str(emergency.id))
    location_cache.purge_user_tracking(str(emergency.user_id))

    payload = {
        "event": "SOS_CANCELLED",
        "emergency_id": str(emergency.id),
        "message": "Emergency call was cancelled yourselve.",
    }
    await manager.send_personal(str(emergency.user_id), payload)
    if emergency.assigned_org_id:
        await manager.send_personal(str(emergency.assigned_org_id), payload)

    return {"message": "Emergency call cancelled successfully and tracking cache purged"}


def _to_response(e: Emergency) -> EmergencyResponse:
    return EmergencyResponse(
        id=str(e.id),
        user_id=str(e.user_id),
        type=e.type.value,
        status=e.status.value,
        assigned_org_id=str(e.assigned_org_id) if e.assigned_org_id else None,
        assigned_volunteer_id=(
            str(e.assigned_volunteer_id) if e.assigned_volunteer_id else None
        ),
        location_lat=e.location_lat,
        location_lng=e.location_lng,
        created_at=e.created_at,
        updated_at=e.updated_at,
    )
