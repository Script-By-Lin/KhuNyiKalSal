"""Emergency endpoints — SOS creation, status, history, completion, cancellation."""

import asyncio
import uuid as uuid_module

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account
from app.models.emergency import Emergency, EmergencyType, EmergencyStatus
from app.core.security import get_current_user
from app.core.permissions import require_role
from app.core.abuse import check_sos_limit
from app.schemas.emergency import SOSRequest, EmergencyResponse, SOSCreatedResponse
from app.services.sos_service import process_sos
from app.websocket.manager import manager

router = APIRouter()


@router.post("/sos", response_model=SOSCreatedResponse)
async def create_sos(
    data: SOSRequest,
    current_user: Account = Depends(require_role("user")),
    db: AsyncSession = Depends(get_db),
):
    """
    Trigger an SOS alert. Creates an emergency record and launches
    background processing (nearest-org search → volunteer alerting → rerouting).
    """
    await check_sos_limit(current_user.id, db)

    try:
        etype = EmergencyType(data.type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid emergency type. Use: fire, medical, crime",
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

    # Launch the SOS flow as a background coroutine
    asyncio.create_task(
        process_sos(
            emergency_id=str(emergency.id),
            user_id=str(current_user.id),
            lat=data.location_lat,
            lng=data.location_lng,
            emergency_type=data.type,
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
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return full emergency history for the current user."""
    result = await db.execute(
        select(Emergency)
        .where(Emergency.user_id == current_user.id)
        .order_by(Emergency.created_at.desc())
    )
    emergencies = result.scalars().all()
    return [_to_response(e) for e in emergencies]


@router.post("/cancel-active")
async def cancel_active_emergencies(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel all active pending/accepted emergencies (used during logout)."""
    await db.execute(
        update(Emergency)
        .where(
            Emergency.user_id == current_user.id,
            Emergency.status.in_([EmergencyStatus.PENDING, EmergencyStatus.ACCEPTED]),
        )
        .values(status=EmergencyStatus.CANCELLED)
    )
    await db.commit()
    return {"message": "Active emergencies cancelled"}


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
    """Mark an emergency as completed and notify victim and responders via WebSocket."""
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
    await db.commit()

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

    return {"message": "Emergency marked as completed"}


@router.put("/{emergency_id}/cancel")
async def cancel_emergency_by_id(
    emergency_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel a specific emergency call by user."""
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

    emergency.status = EmergencyStatus.CANCELLED
    await db.commit()

    payload = {
        "event": "SOS_CANCELLED",
        "emergency_id": str(emergency.id),
        "message": "Emergency call was cancelled by user.",
    }
    await manager.send_personal(str(emergency.user_id), payload)
    if emergency.assigned_org_id:
        await manager.send_personal(str(emergency.assigned_org_id), payload)

    return {"message": "Emergency call cancelled successfully"}


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
