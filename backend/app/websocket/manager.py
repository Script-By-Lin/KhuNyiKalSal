"""WebSocket connection manager — tracks live connections and routes messages using Redis Pub/Sub for multi-worker scaling."""

import json
import logging
import asyncio
from typing import Dict, Any

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
    """Manages WebSocket connections keyed by user_id (string UUID) with Redis Pub/Sub support."""

    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
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
        self.active_connections[user_id] = websocket
        logger.info(f"WebSocket connected locally: {user_id}")
        
        if not self.redis and _redis_available and settings.REDIS_URL:
            await self.connect_redis()

    def disconnect(self, user_id: str):
        self.active_connections.pop(user_id, None)
        logger.info(f"WebSocket disconnected locally: {user_id}")

    async def _send_local(self, user_id: str, data: dict):
        """Send directly to a local connection (internal)."""
        ws = self.active_connections.get(user_id)
        if ws:
            try:
                await ws.send_json(data)
            except Exception as e:
                logger.error(f"Failed to send locally to {user_id}: {e}")
                self.disconnect(user_id)

    async def send_personal(self, user_id: str, data: dict):
        """Send a JSON message to a specific connected user (distributed)."""
        if self.redis:
            payload = {"target": user_id, "data": data}
            await self.redis.publish("ws_broadcast", json.dumps(payload))
        else:
            await self._send_local(user_id, data)

    async def broadcast(self, data: dict, user_ids: list[str]):
        """Send a JSON message to multiple connected users (distributed)."""
        if self.redis:
            payload = {"target": user_ids, "data": data}
            await self.redis.publish("ws_broadcast", json.dumps(payload))
        else:
            for uid in user_ids:
                await self._send_local(uid, data)

    async def broadcast_all(self, data: dict):
        """Send a JSON message to all currently connected WebSockets (distributed)."""
        if self.redis:
            payload = {"target": "ALL", "data": data}
            await self.redis.publish("ws_broadcast", json.dumps(payload))
        else:
            for uid in list(self.active_connections.keys()):
                await self._send_local(uid, data)


# Singleton instance used across the application
manager = ConnectionManager()
