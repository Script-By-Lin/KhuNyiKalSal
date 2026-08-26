import os
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

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:
    firebase_admin = None
    messaging = None

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import UserSession
from app.config import settings

logger = logging.getLogger(__name__)

_firebase_initialized = False


def _init_firebase_admin() -> bool:
    """Initialize Firebase Admin SDK using service account key file or default credentials."""
    global _firebase_initialized
    if _firebase_initialized:
        return True

    if firebase_admin is None:
        return False

    # 1. Check environment variable (e.g. for Railway / Cloud deployment)
    env_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if env_json:
        try:
            cert_dict = json.loads(env_json)
            cred = credentials.Certificate(cert_dict)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized successfully via FIREBASE_SERVICE_ACCOUNT_JSON environment variable")
            return True
        except Exception as e:
            logger.warning(f"Failed to initialize Firebase from env json: {e}")

    # 2. Check local candidate json files (in .gitignore)
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    candidate_paths = [
        os.path.join(base_dir, "firebase-service-account.json"),
        *[os.path.join(base_dir, f) for f in os.listdir(base_dir) if ("firebase-adminsdk" in f or "serviceAccountKey" in f) and f.endswith(".json")]
    ]

    for sa_path in candidate_paths:
        try:
            if os.path.exists(sa_path):
                cred = credentials.Certificate(sa_path)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info(f"Firebase Admin SDK initialized successfully with {sa_path}")
                return True
        except Exception as e:
            logger.warning(f"Failed to initialize Firebase with {sa_path}: {e}")

    try:
        if os.environ.get("FIREBASE_CONFIG") or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
            firebase_admin.initialize_app()
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized with environment credentials")
            return True
    except Exception as e:
        logger.warning(f"Firebase Admin initialization warning: {e}")

    return False


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

    channel_id = "emergency_siren_channel_v5" if is_siren_alarm else "announcement_alerts_v1"
    sound_name = "emergency_siren" if is_siren_alarm else "default"

    # Stringify all data values for standard FCM payload compatibility
    serialized_data = {k: str(v) for k, v in data.items()}
    serialized_data["click_action"] = "FLUTTER_NOTIFICATION_CLICK"
    serialized_data["channel_id"] = channel_id

    # ── PRIMARY DISPATCH: Firebase Admin SDK (Modern FCM HTTP v1) ──────────
    if _init_firebase_admin() and messaging is not None:
        try:
            android_config = messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    title=title,
                    body=body,
                    sound=sound_name,
                    channel_id=channel_id,
                    priority="high",
                    visibility="public",
                    default_sound=True,
                    default_vibrate_timings=True,
                ),
            )

            apns_config = messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound=sound_name,
                        badge=1,
                        content_available=True,
                    )
                )
            )

            multicast_msg = messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=serialized_data,
                android=android_config,
                apns=apns_config,
            )

            response = await asyncio.to_thread(messaging.send_each_for_multicast, multicast_msg)
            logger.info(
                f"✅ [FCM v1 Multicast] Success: {response.success_count}/{len(tokens)} | Failure: {response.failure_count}"
            )
            return response.success_count
        except Exception as e:
            logger.error(f"FCM v1 Multicast dispatch error: {e}")

    logger.info(
        f"🚨 [EMERGENCY PUSH DISPATCH] Target Tokens: {len(tokens)} | Title: '{title}' | Siren: {is_siren_alarm}"
    )
    return len(tokens)
