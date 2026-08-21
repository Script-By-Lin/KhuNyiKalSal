from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, status

from app.websocket.manager import manager
from app.core.security import decode_access_token

router = APIRouter()


@router.websocket("/ws/{user_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    user_id: str,
    token: Optional[str] = Query(None),
):
    """
    Persistent WebSocket connection per user with authentication verification.
    Events pushed server→client: SOS_CREATED, VOLUNTEER_ACCEPTED,
    VOLUNTEER_REJECTED, REROUTE_TRIGGERED, FAMILY_NOTIFIED, etc.
    """
    if token:
        try:
            payload = decode_access_token(token)
            token_sub = payload.get("sub")
            if str(token_sub) != str(user_id):
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                return
        except Exception:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    await manager.connect(user_id, websocket)
    try:
        while True:
            # Keep connection alive; handle pings from client
            data = await websocket.receive_text()
            await manager.send_personal(user_id, {"event": "PONG", "data": data})
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception:
        manager.disconnect(user_id, websocket)
