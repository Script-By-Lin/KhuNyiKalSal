"""
Ephemeral Cache Service — Redis & In-memory real-time location tracking with TTL and auto-purging.
"""

import json
import time
import logging
from typing import Dict, Optional, Any

from app.config import settings

logger = logging.getLogger(__name__)

# Try to import redis
try:
    import redis
    _redis_available = True
except ImportError:
    _redis_available = False


class LocationCacheService:
    """
    Fast, ephemeral real-time tracking cache backed by Redis and local in-memory fallback.
    Locations are stored ONLY in cache during active tracking sessions with a TTL (Time-To-Live).
    Locations are automatically purged when TTL expires or when an emergency is completed/cancelled.
    """

    def __init__(self):
        self._store: Dict[str, Dict[str, Any]] = {}
        self._redis_client = None

        if _redis_available and settings.REDIS_URL:
            try:
                # Initialize Redis client with socket timeout
                self._redis_client = redis.Redis.from_url(
                    settings.REDIS_URL,
                    socket_connect_timeout=2,
                    socket_timeout=2,
                    decode_responses=True,
                )
                # Test ping
                self._redis_client.ping()
                logger.info(f"Connected to Redis cache at {settings.REDIS_URL}")
            except Exception as e:
                logger.warning(f"Redis connection failed ({e}). Falling back to in-memory location cache.")
                self._redis_client = None

    MAX_CACHE_ENTRIES = 500

    def _clean_expired(self):
        """Internal helper to remove expired local cache entries and enforce max memory bound."""
        now = time.time()
        expired_keys = [k for k, v in self._store.items() if v.get("expires_at", 0) < now]
        for key in expired_keys:
            self._store.pop(key, None)
        
        # Enforce memory safety cap
        if len(self._store) > self.MAX_CACHE_ENTRIES:
            # Sort by updated_at ascending and remove oldest entries
            sorted_keys = sorted(
                self._store.keys(),
                key=lambda k: self._store[k].get("updated_at", 0)
            )
            excess = len(self._store) - self.MAX_CACHE_ENTRIES
            for k in sorted_keys[:excess]:
                self._store.pop(k, None)

    def set_realtime_location(
        self,
        entity_id: str,
        emergency_id: str,
        lat: float,
        lng: float,
        role: str = "responder",
        ttl_seconds: int = 300,
    ) -> Dict[str, Any]:
        """Store or update live real-time location in cache with TTL."""
        key = f"tracking:{emergency_id}:{entity_id}"
        expires_at = time.time() + ttl_seconds
        payload = {
            "entity_id": entity_id,
            "emergency_id": emergency_id,
            "lat": lat,
            "lng": lng,
            "role": role,
            "updated_at": time.time(),
            "expires_at": expires_at,
        }

        # Try Redis first
        if self._redis_client:
            try:
                self._redis_client.setex(key, ttl_seconds, json.dumps(payload))
                return payload
            except Exception as e:
                logger.warning(f"Redis setex failed ({e}), using in-memory store.")

        # Local store fallback
        self._clean_expired()
        self._store[key] = payload
        return payload

    def get_realtime_location(
        self, entity_id: str, emergency_id: str
    ) -> Optional[Dict[str, Any]]:
        """Fetch live real-time location from cache if not expired."""
        key = f"tracking:{emergency_id}:{entity_id}"

        # Try Redis
        if self._redis_client:
            try:
                val = self._redis_client.get(key)
                if val:
                    return json.loads(val)
                return None
            except Exception as e:
                logger.warning(f"Redis get failed ({e}), using in-memory store.")

        # Local store fallback
        self._clean_expired()
        item = self._store.get(key)
        if item and item.get("expires_at", 0) >= time.time():
            return item
        return None

    def purge_realtime_tracking(self, emergency_id: str):
        """
        Instantly remove/purge all real-time tracking entries for a given emergency.
        Ensures zero persistent location traces remain after emergency completes/cancels.
        """
        prefix = f"tracking:{emergency_id}:*"

        # Redis purge
        if self._redis_client:
            try:
                keys = self._redis_client.keys(prefix)
                if keys:
                    self._redis_client.delete(*keys)
                logger.info(f"Purged {len(keys)} Redis tracking entries for emergency: {emergency_id}")
            except Exception as e:
                logger.warning(f"Redis purge failed ({e})")

        # Local store purge
        local_prefix = f"tracking:{emergency_id}:"
        matching_keys = [k for k in self._store.keys() if k.startswith(local_prefix)]
        for k in matching_keys:
            self._store.pop(k, None)

    def purge_user_tracking(self, entity_id: str):
        """Purge any real-time tracking entries associated with a specific user/responder ID."""
        pattern = f"tracking:*:{entity_id}"

        # Redis purge
        if self._redis_client:
            try:
                keys = self._redis_client.keys(pattern)
                if keys:
                    self._redis_client.delete(*keys)
            except Exception as e:
                logger.warning(f"Redis user purge failed ({e})")

        # Local store purge
        matching_keys = [k for k in self._store.keys() if f":{entity_id}" in k]
        for k in matching_keys:
            self._store.pop(k, None)


# Singleton instance
location_cache = LocationCacheService()
