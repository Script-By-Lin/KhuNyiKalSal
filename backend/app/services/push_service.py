"""
Push Notification Service — High-priority Emergency FCM Push Dispatcher.
Wakes up devices even when the app is completely closed or locked.
"""

import json
import uuid
import logging
import asyncio
from typing import List, Dict, Any, Optional
import urllib.request
import urllib.error

try:
    import httpx
except ImportError:
    httpx = None

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import UserSession
from app.config import settings

logger = logging.getLogger(__name__)


async def get_user_device_tokens(user_ids: List[uuid.UUID], db: AsyncSession) -> List[str]:
    """Retrieve all active FCM device tokens for the given account IDs."""
    if not user_ids:
        return []
    
    result = await db.execute(
        select(UserSession.fcm_token)
        .where(
            UserSession.user_id.in_(user_ids),
            UserSession.is_active == True,  # noqa: E712
            UserSession.fcm_token.isnot(None),
        )
    )
    tokens = [t for t in result.scalars().all() if t and t.strip()]
    return list(set(tokens))


async def get_all_active_device_tokens(db: AsyncSession) -> List[str]:
    """Retrieve all registered device tokens across all users for broadcast announcements & news."""
    result = await db.execute(
        select(UserSession.fcm_token)
        .where(
            UserSession.is_active == True,  # noqa: E712
            UserSession.fcm_token.isnot(None),
        )
    )
    tokens = [t for t in result.scalars().all() if t and t.strip()]
    return list(set(tokens))


def _send_fcm_urllib(token: str, payload: dict, server_key: str) -> None:
    """Synchronous fallback to deliver FCM push via standard library urllib."""
    try:
        data_bytes = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            "https://fcm.googleapis.com/fcm/send",
            data=data_bytes,
            headers={
                "Authorization": f"key={server_key}",
                "Content-Type": "application/json",
            },
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=8) as response:
            logger.info(f"FCM Push (urllib) for {token[:8]}...: {response.status}")
    except Exception as e:
        logger.error(f"FCM urllib push error: {e}")


async def send_emergency_push(
    tokens: List[str],
    title: str,
    body: str,
    data: Dict[str, Any],
    is_siren_alarm: bool = True,
) -> int:
    """
    Broadcast High-Priority FCM Push Notification with Emergency Siren Channel.
    Wakes up device CPU, illuminates screen with full-screen intent, and plays loud siren.
    """
    if not tokens:
        return 0

    channel_id = "emergency_siren_channel" if is_siren_alarm else "general_alerts_channel"
    sound_name = "emergency_siren" if is_siren_alarm else "default"

    # Stringify all data values for standard FCM payload compatibility
    serialized_data = {k: str(v) for k, v in data.items()}
    serialized_data["click_action"] = "FLUTTER_NOTIFICATION_CLICK"
    serialized_data["channel_id"] = channel_id

    # If FCM Server Key is configured, dispatch HTTP POST to FCM v1 / legacy endpoint
    if settings.FCM_SERVER_KEY:
        try:
            for token in tokens:
                payload = {
                    "to": token,
                    "priority": "high",
                    "notification": {
                        "title": title,
                        "body": body,
                        "sound": sound_name,
                        "android_channel_id": channel_id,
                    },
                    "android": {
                        "priority": "high",
                        "notification": {
                            "channel_id": channel_id,
                            "sound": sound_name,
                            "priority": "high",
                            "visibility": "public",
                        },
                    },
                    "data": serialized_data,
                }
                
                if httpx is not None:
                    async with httpx.AsyncClient(timeout=8.0) as client:
                        headers = {
                            "Authorization": f"key={settings.FCM_SERVER_KEY}",
                            "Content-Type": "application/json",
                        }
                        res = await client.post(
                            "https://fcm.googleapis.com/fcm/send",
                            json=payload,
                            headers=headers,
                        )
                        logger.info(f"FCM Push for {token[:8]}...: {res.status_code}")
                else:
                    await asyncio.to_thread(_send_fcm_urllib, token, payload, settings.FCM_SERVER_KEY)
        except Exception as e:
            logger.error(f"Failed to dispatch FCM push notification: {e}")

    logger.info(
        f"🚨 [EMERGENCY PUSH DISPATCH] Target Tokens: {len(tokens)} | Title: '{title}' | Siren: {is_siren_alarm}"
    )
    return len(tokens)
