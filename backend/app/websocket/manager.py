"""WebSocket connection manager — tracks live connections and routes messages."""

import logging
from typing import Dict

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections keyed by user_id (string UUID)."""

    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_id] = websocket
        logger.info(f"WebSocket connected: {user_id}")

    def disconnect(self, user_id: str):
        self.active_connections.pop(user_id, None)
        logger.info(f"WebSocket disconnected: {user_id}")

    async def send_personal(self, user_id: str, data: dict):
        """Send a JSON message to a specific connected user."""
        ws = self.active_connections.get(user_id)
        if ws:
            try:
                await ws.send_json(data)
            except Exception as e:
                logger.error(f"Failed to send to {user_id}: {e}")
                self.disconnect(user_id)

    async def broadcast(self, data: dict, user_ids: list[str]):
        """Send a JSON message to multiple connected users."""
        for uid in user_ids:
            await self.send_personal(uid, data)

    async def broadcast_all(self, data: dict):
        """Send a JSON message to all currently connected WebSockets."""
        for uid in list(self.active_connections.keys()):
            await self.send_personal(uid, data)


# Singleton instance used across the application
manager = ConnectionManager()
