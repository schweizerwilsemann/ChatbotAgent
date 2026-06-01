import json
import logging

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class RealtimeConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[str, dict[WebSocket, str]] = {}

    async def connect(self, websocket: WebSocket, role: str, user_id: str = "") -> None:
        await websocket.accept()
        self._connections.setdefault(role, {})[websocket] = user_id

    def disconnect(self, websocket: WebSocket, role: str) -> None:
        sockets = self._connections.get(role)
        if not sockets:
            return
        sockets.pop(websocket, None)
        if not sockets:
            self._connections.pop(role, None)

    async def broadcast_to_roles(self, roles: list[str], payload: dict) -> None:
        encoded = json.dumps(payload, ensure_ascii=False)
        stale: list[tuple[str, WebSocket]] = []
        target_user_ids = _target_user_ids(payload)
        for role in roles:
            for websocket, user_id in list(self._connections.get(role, {}).items()):
                if target_user_ids and user_id not in target_user_ids:
                    continue
                try:
                    await websocket.send_text(encoded)
                except Exception:
                    logger.debug("Dropping stale websocket for role %s", role)
                    stale.append((role, websocket))
        for role, websocket in stale:
            self.disconnect(websocket, role)


realtime_manager = RealtimeConnectionManager()


def _target_user_ids(payload: dict) -> set[str]:
    nested_payload = payload.get("payload")
    if not isinstance(nested_payload, dict):
        return set()
    raw_targets = nested_payload.get("target_user_ids")
    if not isinstance(raw_targets, list):
        return set()
    return {str(item) for item in raw_targets}
