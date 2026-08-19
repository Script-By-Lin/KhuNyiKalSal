"""WebSocket connection manager — tracks live multi-device connections and routes messages using Redis Pub/Sub for distributed scaling."""

import json
import logging
import asyncio
from typing import Dict, Set, Any, Optional, List

from fastapi import WebSocket
from app.config import settings

logger = logging.getLogger(__name__)

# Try to import redis.asyncio for Pub/Sub
try:
    import redis.asyncio as aioredis
    _redis_available = True
except ImportError:
    _redis_available = False


class ConnectionManager:
    """
    Manages WebSocket connections keyed by user_id (string UUID).
    Supports multiple concurrent connections per user (e.g. mobile app + tablet + desktop dispatcher)
    and distributed synchronization via Redis Pub/Sub.
    """

    def __init__(self):
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        self.redis = None
        self.pubsub = None
        self.pubsub_task = None
        
    async def connect_redis(self):
        if _redis_available and settings.REDIS_URL and not self.redis:
            try:
                self.redis = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
                self.pubsub = self.redis.pubsub()
                await self.pubsub.subscribe("ws_broadcast")
                self.pubsub_task = asyncio.create_task(self._listen_to_redis())
                logger.info("Connected to Redis Pub/Sub for WebSockets")
            except Exception as e:
                logger.warning(f"Redis Pub/Sub connection failed ({e}). Falling back to local broadcasts.")
                self.redis = None

    async def _listen_to_redis(self):
        try:
            async for message in self.pubsub.listen():
                if message["type"] == "message":
                    payload = json.loads(message["data"])
                    target = payload.get("target")
                    data = payload.get("data")
                    
                    if target == "ALL":
                        # Send to all connected to this worker
                        for uid in list(self.active_connections.keys()):
                            await self._send_local(uid, data)
                    elif isinstance(target, list):
                        # Send to specific users if they are connected to this worker
                        for uid in target:
                            await self._send_local(uid, data)
                    elif isinstance(target, str):
                        await self._send_local(target, data)
        except Exception as e:
            logger.error(f"Redis PubSub listener error: {e}")

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)
        logger.info(f"WebSocket connected: user {user_id} (active sockets: {len(self.active_connections[user_id])})")
        
        if not self.redis and _redis_available and settings.REDIS_URL:
            await self.connect_redis()

    def disconnect(self, user_id: str, websocket: Optional[WebSocket] = None):
        if user_id in self.active_connections:
            if websocket is not None:
                self.active_connections[user_id].discard(websocket)
            else:
                self.active_connections[user_id].clear()

            if not self.active_connections[user_id]:
                self.active_connections.pop(user_id, None)
        logger.info(f"WebSocket disconnected: user {user_id}")

    async def _send_local(self, user_id: str, data: dict):
        """Send message to all live connections for a given user."""
        sockets = self.active_connections.get(user_id)
        if not sockets:
            return

        dead_sockets = set()
        for ws in list(sockets):
            try:
                await ws.send_json(data)
            except Exception as e:
                logger.debug(f"Socket send failed for user {user_id}: {e}")
                dead_sockets.add(ws)

        for dead_ws in dead_sockets:
            sockets.discard(dead_ws)

        if not sockets:
            self.active_connections.pop(user_id, None)

    async def send_personal(self, user_id: str, data: dict):
        """Send a JSON message to a specific connected user (distributed)."""
        if self.redis:
            try:
                payload = {"target": user_id, "data": data}
                await self.redis.publish("ws_broadcast", json.dumps(payload))
                return
            except Exception:
                pass
        await self._send_local(user_id, data)

    async def broadcast(self, data: dict, user_ids: Optional[List[str]] = None):
        """Send a JSON message to multiple connected users or all users if user_ids is None."""
        if not user_ids:
            await self.broadcast_all(data)
            return

        if self.redis:
            try:
                payload = {"target": user_ids, "data": data}
                await self.redis.publish("ws_broadcast", json.dumps(payload))
                return
            except Exception:
                pass
        for uid in user_ids:
            await self._send_local(uid, data)

    async def broadcast_all(self, data: dict):
        """Send a JSON message to all currently connected WebSockets (distributed)."""
        if self.redis:
            try:
                payload = {"target": "ALL", "data": data}
                await self.redis.publish("ws_broadcast", json.dumps(payload))
                return
            except Exception:
                pass
        for uid in list(self.active_connections.keys()):
            await self._send_local(uid, data)

    def get_stats(self) -> Dict[str, Any]:
        """Diagnostic stats for health checks."""
        total_sockets = sum(len(s) for s in self.active_connections.values())
        return {
            "connected_users": len(self.active_connections),
            "total_active_sockets": total_sockets,
            "redis_connected": bool(self.redis),
        }


# Singleton instance used across the application
manager = ConnectionManager()
