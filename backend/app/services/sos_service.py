"""
SOS service — orchestrates the full emergency flow:
1. Create emergency event
2. Notify family contacts
3. Find nearest organizations (Haversine)
4. Alert volunteers via WebSocket
5. Wait for response or timeout
6. Reroute to next organization if needed
"""

import asyncio
import uuid
import logging
from typing import Optional

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_maker
from app.models import Emergency, EmergencyStatus, Volunteer, UserProfile
from app.services.location_service import find_nearest_organizations
from app.services.notification_service import notify_family
from app.websocket.manager import manager
from app.config import settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Volunteer response tracker (in-memory, per-process)
# ---------------------------------------------------------------------------

class EmergencyResponseTracker:
    """
    Tracks volunteer responses for active SOS events.
    Uses asyncio.Event to allow the SOS processing coroutine to await
    a volunteer's accept or detect when all have rejected.
    """

    def __init__(self):
        self._events: dict[str, asyncio.Event] = {}
        self._responses: dict[str, Optional[dict]] = {}
        self._expected: dict[str, int] = {}
        self._rejections: dict[str, int] = {}
        self._rejected_ids: dict[str, set[str]] = {}

    def add_rejection(self, emergency_id: str, account_id: str):
        if emergency_id not in self._rejected_ids:
            self._rejected_ids[emergency_id] = set()
        self._rejected_ids[emergency_id].add(account_id)

    def is_rejected_by(self, emergency_id: str, account_id: str) -> bool:
        return account_id in self._rejected_ids.get(emergency_id, set())

    def get_rejected(self, emergency_id: str) -> set[str]:
        return self._rejected_ids.get(emergency_id, set())

    def create(self, emergency_id: str, num_volunteers: int):
        self._events[emergency_id] = asyncio.Event()
        self._responses[emergency_id] = None
        self._expected[emergency_id] = num_volunteers
        self._rejections[emergency_id] = 0

    async def wait_for_response(
        self, emergency_id: str, timeout: float
    ) -> Optional[dict]:
        event = self._events.get(emergency_id)
        if not event:
            return None
        try:
            await asyncio.wait_for(event.wait(), timeout=timeout)
            return self._responses.get(emergency_id)
        except asyncio.TimeoutError:
            return None

    def respond(self, emergency_id: str, volunteer_id: str, accepted: bool):
        if accepted:
            self._responses[emergency_id] = {
                "volunteer_id": volunteer_id,
                "accepted": True,
            }
            event = self._events.get(emergency_id)
            if event:
                event.set()
        else:
            self.add_rejection(emergency_id, volunteer_id)

    def cleanup(self, emergency_id: str):
        self._events.pop(emergency_id, None)
        self._responses.pop(emergency_id, None)
        self._expected.pop(emergency_id, None)
        self._rejections.pop(emergency_id, None)


# Singleton
response_tracker = EmergencyResponseTracker()


# ---------------------------------------------------------------------------
# SOS processing background task
# ---------------------------------------------------------------------------

async def process_sos(
    emergency_id: str,
    user_id: str,
    lat: float,
    lng: float,
    emergency_type: str,
):
    """
    Background task launched after an SOS is created.
    Broadcasts the alert to ALL relevant organisations and their volunteers
    at once. Does NOT auto-reroute — organisations manually accept or reject.
    """
    async with async_session_maker() as db:
        try:
            # ── Gather user info for volunteer alerts ──────────────────
            result = await db.execute(
                select(UserProfile).where(
                    UserProfile.account_id == uuid.UUID(user_id)
                )
            )
            profile = result.scalar_one_or_none()
            user_info = {
                "full_name": profile.full_name if profile else "Unknown",
                "phone_number": profile.phone_number if profile else "",
                "blood_type": profile.blood_type or "Unknown",
                "medical_conditions": profile.medical_conditions or "None",
            }

            # ── Notify family contacts ─────────────────────────────────
            await notify_family(user_id, emergency_type, lat, lng, db)

            # ── Find nearest organisations (matching emergency_type) ────
            org_distances = await find_nearest_organizations(
                lat, lng, db, emergency_type=emergency_type
            )

            # ── Build alert payload ─────────────────────────────────────
            if org_distances:
                best_org = org_distances[0][0]
                best_org_id = str(best_org.account_id)

                # Assign emergency strictly to the nearest matching org
                await db.execute(
                    update(Emergency)
                    .where(Emergency.id == uuid.UUID(emergency_id))
                    .values(assigned_org_id=best_org.account_id)
                )
                await db.commit()

                alert_data = {
                    "event": "SOS_CREATED",
                    "emergency_id": emergency_id,
                    "type": emergency_type,
                    "location": {"lat": lat, "lng": lng},
                    "user_info": user_info,
                    "organization": best_org.org_name,
                }

                notified_uids = set()

                # Send WebSocket alert ONLY to the assigned organization account
                await manager.send_personal(best_org_id, alert_data)
                notified_uids.add(best_org_id)

                # Send WebSocket alert ONLY to volunteers belonging to this specific organization
                vol_result = await db.execute(
                    select(Volunteer).where(
                        Volunteer.org_id == best_org.account_id,
                        Volunteer.is_active == True,  # noqa: E712
                    )
                )
                for v in vol_result.scalars().all():
                    vid = str(v.account_id)
                    await manager.send_personal(vid, alert_data)
                    notified_uids.add(vid)

                logger.info(
                    f"Emergency {emergency_id} assigned strictly to {best_org.org_name} ({len(notified_uids)} recipients)"
                )
            else:
                logger.warning(f"No active organizations found for emergency {emergency_id}")

        except Exception as e:
            logger.error(f"Error processing SOS {emergency_id}: {e}", exc_info=True)
            await manager.send_personal(user_id, {
                "event": "SOS_ERROR",
                "emergency_id": emergency_id,
                "message": "An error occurred. Please try again.",
            })


async def _update_status(
    db: AsyncSession, emergency_id: str, status: EmergencyStatus
):
    await db.execute(
        update(Emergency)
        .where(Emergency.id == uuid.UUID(emergency_id))
        .values(status=status)
    )
    await db.commit()

