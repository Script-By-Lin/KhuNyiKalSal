"""WebSocket endpoint for real-time communication."""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.websocket.manager import manager

router = APIRouter()


@router.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    """
    Persistent WebSocket connection per user.
    Events pushed server→client: SOS_CREATED, VOLUNTEER_ACCEPTED,
    VOLUNTEER_REJECTED, REROUTE_TRIGGERED, FAMILY_NOTIFIED, etc.
    """
    await manager.connect(user_id, websocket)
    try:
        while True:
            # Keep connection alive; handle pings from client
            data = await websocket.receive_text()
            await manager.send_personal(user_id, {"event": "PONG", "data": data})
    except WebSocketDisconnect:
        manager.disconnect(user_id)
