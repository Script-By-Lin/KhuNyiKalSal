"""Announcements API — Official alerts, weather warnings, blood drive bulletins, and general news."""

import uuid as uuid_module
from typing import Optional, List
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account
from app.models.announcement import Announcement
from app.core.permissions import require_role
from app.websocket.manager import manager

router = APIRouter()


class AnnouncementResponse(BaseModel):
    id: str
    title: str
    content: str
    category: str
    author_name: str
    is_pinned: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CreateAnnouncementRequest(BaseModel):
    title: str
    content: str
    category: str = "General"
    author_name: Optional[str] = "Emergency Command Center"
    is_pinned: bool = False


class UpdateAnnouncementRequest(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    author_name: Optional[str] = None
    is_pinned: Optional[bool] = None
    is_active: Optional[bool] = None


class BroadcastEphemeralRequest(BaseModel):
    title: str
    message: str
    category: str = "DAILY_QUOTE"  # 'DAILY_QUOTE', 'MISSING_PERSON', 'COMMUNITY_NOTE', 'INSPIRATION', 'QUICK_ALERT'
    author_name: Optional[str] = "Command Center"
    sound_type: Optional[str] = "default"


@router.get("", response_model=List[AnnouncementResponse])
@router.get("/", response_model=List[AnnouncementResponse])
async def list_announcements(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    category: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    """Retrieve all active announcements sorted by pinned status and creation date."""
    query = select(Announcement).where(Announcement.is_active == True)  # noqa: E712
    if category and category.strip():
        query = query.where(Announcement.category == category.strip())

    query = query.order_by(Announcement.is_pinned.desc(), Announcement.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    announcements = result.scalars().all()

    return [
        AnnouncementResponse(
            id=str(a.id),
            title=a.title,
            content=a.content,
            category=a.category,
            author_name=a.author_name,
            is_pinned=a.is_pinned,
            is_active=a.is_active,
            created_at=a.created_at,
            updated_at=a.updated_at,
        )
        for a in announcements
    ]


@router.post("", response_model=AnnouncementResponse, status_code=status.HTTP_201_CREATED)
async def create_announcement(
    data: CreateAnnouncementRequest,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to create and broadcast an announcement."""
    announcement = Announcement(
        title=data.title.strip(),
        content=data.content.strip(),
        category=data.category.strip(),
        author_name=data.author_name or "Emergency Command Center",
        is_pinned=data.is_pinned,
        is_active=True,
    )
    db.add(announcement)
    await db.commit()
    await db.refresh(announcement)

    # Real-time WebSocket broadcast to all connected clients
    alert_payload = {
        "event": "NEW_ANNOUNCEMENT",
        "announcement_id": str(announcement.id),
        "title": announcement.title,
        "content": announcement.content,
        "category": announcement.category,
        "author_name": announcement.author_name,
        "is_pinned": announcement.is_pinned,
        "created_at": announcement.created_at.isoformat(),
    }
    try:
        await manager.broadcast_all(alert_payload)
    except Exception:
        pass

    # Push Notification dispatch to all user devices (delivered even if app is closed)
    try:
        from app.services.push_service import get_all_active_device_tokens, send_emergency_push
        tokens = await get_all_active_device_tokens(db)
        if tokens:
            prefix = "🚨 [URGENT BULLETIN]" if announcement.is_pinned else "📢 [OFFICIAL ANNOUNCEMENT]"
            await send_emergency_push(
                tokens=tokens,
                title=f"{prefix} {announcement.title}",
                body=f"{announcement.content[:140]}..." if len(announcement.content) > 140 else announcement.content,
                data={
                    "type": "ANNOUNCEMENT",
                    "event": "NEW_ANNOUNCEMENT",
                    "announcement_id": str(announcement.id),
                    "route": "/announcements",
                    "title": announcement.title,
                    "content": announcement.content,
                    "category": announcement.category,
                },
                is_siren_alarm=True,
            )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"Failed to dispatch announcement push: {e}")

    return AnnouncementResponse(
        id=str(announcement.id),
        title=announcement.title,
        content=announcement.content,
        category=announcement.category,
        author_name=announcement.author_name,
        is_pinned=announcement.is_pinned,
        is_active=announcement.is_active,
        created_at=announcement.created_at,
        updated_at=announcement.updated_at,
    )


@router.post("/broadcast-ephemeral", status_code=status.HTTP_200_OK)
async def broadcast_ephemeral_quote_or_alert(
    data: BroadcastEphemeralRequest,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """
    Admin endpoint to push a real-time Daily Quote, Missing Person Alert, or Ephemeral Bulletin.
    DOES NOT store anything in the database!
    Delivers instant WebSocket notification and FCM/APNs push notification with sound to all users.
    """
    title = data.title.strip()
    message = data.message.strip()
    category = data.category.strip()

    # 1. Real-time WebSocket broadcast to all connected active clients
    display_title = "Khu Nyi Kal Sal" if category == "DAILY_QUOTE" else (title if title else "Khu Nyi Kal Sal")

    ws_payload = {
        "event": "EPHEMERAL_BROADCAST",
        "type": "EPHEMERAL_BROADCAST",
        "category": category,
        "title": display_title,
        "message": message,
        "author_name": data.author_name or current_user.full_name or "Command Center",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    try:
        await manager.broadcast_all(ws_payload)
    except Exception:
        pass

    # 2. Push Notification dispatch to all registered user device tokens
    recipient_count = 0
    try:
        from app.services.push_service import get_all_active_device_tokens, send_emergency_push
        tokens = await get_all_active_device_tokens(db)
        recipient_count = len(tokens)
        if tokens:
            if category == "DAILY_QUOTE":
                push_title = "Khu Nyi Kal Sal"
            elif category == "MISSING_PERSON":
                push_title = f"🔍 [MISSING PERSON] {title}"
            else:
                push_title = title if title else "Khu Nyi Kal Sal"

            await send_emergency_push(
                tokens=tokens,
                title=push_title,
                body=message,
                data={
                    "type": "EPHEMERAL_BROADCAST",
                    "event": "EPHEMERAL_BROADCAST",
                    "category": category,
                    "title": push_title,
                    "message": message,
                },
                is_siren_alarm=True,
            )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"Failed to dispatch ephemeral push: {e}")

    return {
        "success": True,
        "message": "Ephemeral broadcast dispatched successfully to all user devices (not saved to DB).",
        "recipients_count": recipient_count,
        "title": display_title,
        "category": category,
    }


@router.put("/{announcement_id}", response_model=AnnouncementResponse)
async def update_announcement(
    announcement_id: str,
    data: UpdateAnnouncementRequest,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to update an existing announcement."""
    try:
        a_uuid = uuid_module.UUID(announcement_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid announcement ID format")

    res = await db.execute(select(Announcement).where(Announcement.id == a_uuid))
    announcement = res.scalar_one_or_none()
    if not announcement:
        raise HTTPException(status_code=404, detail="Announcement not found")

    update_dict = data.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(announcement, field, value)

    await db.commit()
    await db.refresh(announcement)

    return AnnouncementResponse(
        id=str(announcement.id),
        title=announcement.title,
        content=announcement.content,
        category=announcement.category,
        author_name=announcement.author_name,
        is_pinned=announcement.is_pinned,
        is_active=announcement.is_active,
        created_at=announcement.created_at,
        updated_at=announcement.updated_at,
    )


@router.delete("/{announcement_id}")
async def delete_announcement(
    announcement_id: str,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to soft-delete or remove an announcement."""
    try:
        a_uuid = uuid_module.UUID(announcement_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid announcement ID format")

    res = await db.execute(select(Announcement).where(Announcement.id == a_uuid))
    announcement = res.scalar_one_or_none()
    if not announcement:
        raise HTTPException(status_code=404, detail="Announcement not found")

    await db.delete(announcement)
    await db.commit()
    return {"message": "Announcement deleted successfully"}
