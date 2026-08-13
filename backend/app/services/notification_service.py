"""Family & Emergency Group Alert notification service."""

import uuid
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_profile import UserProfile
from app.models.family import FamilyMember, FamilyAlert
from app.websocket.manager import manager

logger = logging.getLogger(__name__)


async def notify_family(
    user_id: str,
    emergency_type: str,
    lat: float,
    lng: float,
    db: AsyncSession,
    emergency_id: str = None,
):
    """
    Notify all family members in the user's Family Group:
    1. Create a persistent FamilyAlert record.
    2. Push WebSocket alert messages to all connected family members.
    3. Log SMS fallback for listed emergency contacts.
    """
    user_uuid = uuid.UUID(user_id)
    result = await db.execute(
        select(UserProfile).where(UserProfile.account_id == user_uuid)
    )
    profile = result.scalar_one_or_none()
    sender_name = profile.full_name if profile else "Family Member"

    # Find if user belongs to a FamilyGroup
    mem_res = await db.execute(
        select(FamilyMember).where(FamilyMember.account_id == user_uuid)
    )
    user_member = mem_res.scalar_one_or_none()

    notified_count = 0

    if user_member:
        family_id = user_member.family_id
        relationship = user_member.relationship

        # Create persistent FamilyAlert record
        alert_msg = f"EMERGENCY ALERT! Your {relationship} ({sender_name}) triggered a {emergency_type.upper()} SOS at location ({lat}, {lng})."
        
        family_alert = FamilyAlert(
            family_id=family_id,
            sender_id=user_uuid,
            emergency_id=uuid.UUID(emergency_id) if emergency_id else None,
            emergency_type=emergency_type,
            location_lat=lat,
            location_lng=lng,
            message=alert_msg,
        )
        db.add(family_alert)
        await db.commit()

        # Fetch all family group members
        all_mems_res = await db.execute(
            select(FamilyMember).where(FamilyMember.family_id == family_id)
        )
        all_members = all_mems_res.scalars().all()

        alert_payload = {
            "event": "FAMILY_SOS_ALERT",
            "family_id": str(family_id),
            "sender_id": user_id,
            "sender_name": sender_name,
            "relationship": relationship,
            "emergency_id": emergency_id,
            "emergency_type": emergency_type,
            "location": {"lat": lat, "lng": lng},
            "message": alert_msg,
        }

        # Broadcast alert to all connected family members (except sender)
        for m in all_members:
            m_uid = str(m.account_id)
            if m_uid != user_id:
                await manager.send_personal(m_uid, alert_payload)
                notified_count += 1

        logger.info(f"Pushed Family Emergency Alert to {notified_count} family members for group {family_id}")

    # Fallback to profile emergency contacts
    if profile and profile.emergency_contacts:
        for contact in profile.emergency_contacts:
            logger.info(
                f"SMS FALLBACK ALERT → {contact.get('name', 'Unknown')} "
                f"({contact.get('phone', '')}): SOS {emergency_type} at ({lat}, {lng}) from {sender_name}"
            )

    # Confirm notification status to the victim user
    await manager.send_personal(user_id, {
        "event": "FAMILY_NOTIFIED",
        "contacts_notified": max(notified_count, len(profile.emergency_contacts) if profile and profile.emergency_contacts else 0),
    })
