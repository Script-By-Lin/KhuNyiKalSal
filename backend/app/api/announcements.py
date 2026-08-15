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
    try:
        await manager.broadcast_all({
            "event": "NEW_ANNOUNCEMENT",
            "announcement_id": str(announcement.id),
            "title": announcement.title,
            "category": announcement.category,
        })
    except Exception:
        pass

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
