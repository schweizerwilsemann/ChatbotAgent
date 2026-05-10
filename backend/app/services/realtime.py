import json
import logging

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class RealtimeConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, role: str) -> None:
        await websocket.accept()
        self._connections.setdefault(role, set()).add(websocket)

    def disconnect(self, websocket: WebSocket, role: str) -> None:
        sockets = self._connections.get(role)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(role, None)

    async def broadcast_to_roles(self, roles: list[str], payload: dict) -> None:
        encoded = json.dumps(payload, ensure_ascii=False)
        stale: list[tuple[str, WebSocket]] = []
        for role in roles:
            for websocket in list(self._connections.get(role, set())):
                try:
                    await websocket.send_text(encoded)
                except Exception:
                    logger.debug("Dropping stale websocket for role %s", role)
                    stale.append((role, websocket))
        for role, websocket in stale:
            self.disconnect(websocket, role)


realtime_manager = RealtimeConnectionManager()
