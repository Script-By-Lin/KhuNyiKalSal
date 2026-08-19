"""
SOS service — orchestrates the full emergency flow:
1. Create emergency event
2. Notify family contacts
3. Find nearest organizations (Haversine)
4. Alert assigned organization & volunteers via WebSocket + FCM Push
5. Wait up to 3 minutes (180s) for accept or reject
6. Auto-reroute to next organization if timed out or rejected
7. Cancel and inform victim if all organizations are exhausted
"""

import asyncio
import uuid
import logging
from typing import Optional

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_maker
from app.models import Emergency, EmergencyStatus, Volunteer, UserProfile, Organization
from app.services.location_service import find_nearest_organizations
from app.services.notification_service import notify_family
from app.websocket.manager import manager
from app.config import settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Volunteer / Organization response tracker (in-memory, per-process)
# ---------------------------------------------------------------------------

class EmergencyResponseTracker:
    """
    Tracks volunteer and organization responses for active SOS events.
    Uses asyncio.Event to allow the SOS processing coroutine to await
    a volunteer's accept or detect when rejected / timed out.
    """

    def __init__(self):
        self._events: dict[str, asyncio.Event] = {}
        self._responses: dict[str, Optional[dict]] = {}
        self._rejected_ids: dict[str, set[str]] = {}

    def add_rejection(self, emergency_id: str, account_id: str):
        if emergency_id not in self._rejected_ids:
            self._rejected_ids[emergency_id] = set()
        self._rejected_ids[emergency_id].add(str(account_id))

    def is_rejected_by(self, emergency_id: str, account_id: str) -> bool:
        return str(account_id) in self._rejected_ids.get(emergency_id, set())

    def get_rejected(self, emergency_id: str) -> set[str]:
        return self._rejected_ids.get(emergency_id, set())

    def create(self, emergency_id: str, num_volunteers: int = 0):
        self._events[emergency_id] = asyncio.Event()
        self._responses[emergency_id] = None

    def reset_event(self, emergency_id: str):
        """Reset wait event for the next organization round."""
        self._events[emergency_id] = asyncio.Event()
        self._responses[emergency_id] = None

    async def wait_for_response(
        self, emergency_id: str, timeout: float
    ) -> Optional[dict]:
        event = self._events.get(emergency_id)
        if not event:
            event = asyncio.Event()
            self._events[emergency_id] = event
        try:
            await asyncio.wait_for(event.wait(), timeout=timeout)
            return self._responses.get(emergency_id)
        except asyncio.TimeoutError:
            return None

    def respond(self, emergency_id: str, volunteer_id: str, accepted: bool):
        if accepted:
            self._responses[emergency_id] = {
                "volunteer_id": str(volunteer_id),
                "accepted": True,
            }
            event = self._events.get(emergency_id)
            if event:
                event.set()
        else:
            self.add_rejection(emergency_id, str(volunteer_id))
            self._responses[emergency_id] = {
                "volunteer_id": str(volunteer_id),
                "accepted": False,
            }
            event = self._events.get(emergency_id)
            if event:
                event.set()

    def cleanup(self, emergency_id: str):
        self._events.pop(emergency_id, None)
        self._responses.pop(emergency_id, None)
        self._rejected_ids.pop(emergency_id, None)


# Singleton
response_tracker = EmergencyResponseTracker()


# ---------------------------------------------------------------------------
# SOS processing background task with 3-minute auto-reroute
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
    Orchestrates the 3-minute cascading auto-reroute loop:
    1. Gathers user info and notifies family safety contacts.
    2. Finds nearest matching organizations.
    3. Assigns top candidate organization and broadcasts alerts (WS + FCM).
    4. Waits up to 3 minutes (180s) for accept or reject.
    5. If accepted: completes cleanly.
    6. If timed out / rejected: reassigns to next nearest organization and repeats.
    7. If all organizations exhausted: cancels emergency and notifies victim.
    """
    timeout_seconds = getattr(settings, "SOS_REROUTE_TIMEOUT_SECONDS", 180)
    response_tracker.create(emergency_id)

    try:
        # Step 1: Gather victim profile info
        user_info = {
            "full_name": "Citizen in Need",
            "phone_number": "",
            "blood_type": "Unknown",
            "medical_conditions": "None",
        }
        async with async_session_maker() as db:
            result = await db.execute(
                select(UserProfile).where(
                    UserProfile.account_id == uuid.UUID(user_id)
                )
            )
            profile = result.scalar_one_or_none()
            if profile:
                user_info = {
                    "full_name": profile.full_name or "Citizen in Need",
                    "phone_number": profile.get_decrypted_phone() or "",
                    "blood_type": profile.blood_type or "Unknown",
                    "medical_conditions": profile.medical_conditions or "None",
                }

            # Notify family contacts once at start
            await notify_family(user_id, emergency_type, lat, lng, db, emergency_id=emergency_id)

        # Step 2: Cascading loop across organizations
        attempt = 0
        while True:
            attempt += 1
            candidate_org = None
            current_org_id = None

            async with async_session_maker() as db:
                # Re-check emergency status in DB
                em_res = await db.execute(
                    select(Emergency).where(Emergency.id == uuid.UUID(emergency_id))
                )
                emergency = em_res.scalar_one_or_none()
                if not emergency or emergency.status != EmergencyStatus.PENDING:
                    logger.info(
                        f"Emergency {emergency_id} is no longer PENDING (status={emergency.status if emergency else 'None'}). Exiting loop."
                    )
                    break

                # Query nearest organizations and filter out rejected/timed-out ones
                rejected_ids = response_tracker.get_rejected(emergency_id)
                org_distances = await find_nearest_organizations(
                    lat, lng, db, emergency_type=emergency_type
                )

                for org, dist in org_distances:
                    if str(org.account_id) not in rejected_ids:
                        candidate_org = org
                        break

                if not candidate_org:
                    # All available organizations exhausted
                    logger.warning(f"All organizations exhausted for emergency {emergency_id}. Cancelling.")
                    emergency.status = EmergencyStatus.CANCELLED
                    await db.commit()

                    await manager.send_personal(user_id, {
                        "event": "SOS_CANCELLED",
                        "emergency_id": emergency_id,
                        "message": "All nearby rescue organizations are unavailable or timed out. Please contact emergency services directly.",
                    })
                    break

                current_org_id = str(candidate_org.account_id)
                emergency.assigned_org_id = candidate_org.account_id
                await db.commit()

                # Notify victim: SOS_ASSIGNED on first round, REROUTE_TRIGGERED on subsequent rounds
                if attempt == 1:
                    await manager.send_personal(user_id, {
                        "event": "SOS_ASSIGNED",
                        "emergency_id": emergency_id,
                        "assigned_org_id": current_org_id,
                        "org_name": candidate_org.org_name,
                    })
                else:
                    await manager.send_personal(user_id, {
                        "event": "REROUTE_TRIGGERED",
                        "emergency_id": emergency_id,
                        "message": f"Re-routing to {candidate_org.org_name} (ETA nearest responder)...",
                        "assigned_org_id": current_org_id,
                        "org_name": candidate_org.org_name,
                    })

                # Prepare alert payload
                alert_data = {
                    "event": "SOS_CREATED",
                    "emergency_id": emergency_id,
                    "type": emergency_type,
                    "location": {"lat": lat, "lng": lng},
                    "user_info": user_info,
                    "organization": candidate_org.org_name,
                }

                notified_uids = {current_org_id}
                target_account_uuids = [candidate_org.account_id]
                await manager.send_personal(current_org_id, alert_data)

                # Broadcast to volunteers associated with this org or free volunteers
                vol_result = await db.execute(
                    select(Volunteer).where(
                        Volunteer.is_active == True,  # noqa: E712
                        (Volunteer.org_id == candidate_org.account_id) | (Volunteer.org_id.is_(None)),
                    )
                )
                for v in vol_result.scalars().all():
                    vid_str = str(v.account_id)
                    if vid_str not in rejected_ids:
                        await manager.send_personal(vid_str, alert_data)
                        notified_uids.add(vid_str)
                        target_account_uuids.append(v.account_id)

                # Send FCM Push with siren alarm
                try:
                    from app.services.push_service import get_user_device_tokens, send_emergency_push
                    org_and_vol_tokens = await get_user_device_tokens(list(set(target_account_uuids)), db)
                    if org_and_vol_tokens:
                        victim_name = user_info.get("full_name", "Citizen")
                        await send_emergency_push(
                            tokens=org_and_vol_tokens,
                            title=f"🚨 CRITICAL SOS: {emergency_type.upper()} EMERGENCY",
                            body=f"Patient: {victim_name} at ({lat:.4f}, {lng:.4f}). Tap to navigate / dispatch.",
                            data=alert_data,
                            is_siren_alarm=True,
                        )
                except Exception as pe:
                    logger.warning(f"FCM push dispatch failed: {pe}")

                logger.info(
                    f"Emergency {emergency_id} (attempt {attempt}) assigned to {candidate_org.org_name}. Waiting up to {timeout_seconds}s for response..."
                )

            # Reset the response event for this round
            response_tracker.reset_event(emergency_id)

            # Wait for accept or timeout (180s)
            resp = await response_tracker.wait_for_response(emergency_id, timeout=timeout_seconds)

            # Check DB again to confirm if accepted
            async with async_session_maker() as db:
                em_check = await db.execute(
                    select(Emergency).where(Emergency.id == uuid.UUID(emergency_id))
                )
                current_em = em_check.scalar_one_or_none()
                if current_em and current_em.status == EmergencyStatus.ACCEPTED:
                    logger.info(f"Emergency {emergency_id} confirmed ACCEPTED in database. Flow complete.")
                    break
                elif current_em and current_em.status in (EmergencyStatus.CANCELLED, EmergencyStatus.COMPLETED):
                    logger.info(f"Emergency {emergency_id} status is {current_em.status}. Exiting loop.")
                    break

            if resp and resp.get("accepted"):
                logger.info(f"Emergency {emergency_id} accepted via tracker. Flow complete.")
                break

            # If here, the 3-minute timeout expired or rejection occurred
            reason = "rejected" if (resp and not resp.get("accepted")) else f"timed out ({timeout_seconds}s)"
            logger.warning(
                f"Emergency {emergency_id} {reason} by {candidate_org.org_name} ({current_org_id}). Auto-rerouting to next organization..."
            )
            response_tracker.add_rejection(emergency_id, current_org_id)

    except Exception as e:
        logger.error(f"Error in process_sos for {emergency_id}: {e}", exc_info=True)
        await manager.send_personal(user_id, {
            "event": "SOS_ERROR",
            "emergency_id": emergency_id,
            "message": "An error occurred during emergency dispatch.",
        })
    finally:
        response_tracker.cleanup(emergency_id)


async def _update_status(
    db: AsyncSession, emergency_id: str, status: EmergencyStatus
):
    await db.execute(
        update(Emergency)
        .where(Emergency.id == uuid.UUID(emergency_id))
        .values(status=status)
    )
    await db.commit()

