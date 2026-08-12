"""Family/emergency contact notification service."""

import uuid
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_profile import UserProfile
from app.websocket.manager import manager

logger = logging.getLogger(__name__)


async def notify_family(
    user_id: str,
    emergency_type: str,
    lat: float,
    lng: float,
    db: AsyncSession,
):
    """
    Notify all emergency contacts listed in the user's profile.
    Currently logs the notification; in production, send SMS or push.
    """
    result = await db.execute(
        select(UserProfile).where(UserProfile.account_id == uuid.UUID(user_id))
    )
    profile = result.scalar_one_or_none()
    if not profile or not profile.emergency_contacts:
        return

    for contact in profile.emergency_contacts:
        logger.info(
            f"FAMILY ALERT → {contact.get('name', 'Unknown')} "
            f"({contact.get('phone', '')}): "
            f"SOS {emergency_type} at ({lat}, {lng}) from {profile.full_name}"
        )

    # Confirm to the user that family was notified
    await manager.send_personal(user_id, {
        "event": "FAMILY_NOTIFIED",
        "contacts_notified": len(profile.emergency_contacts),
    })
