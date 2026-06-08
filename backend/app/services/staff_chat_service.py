import json
import logging
import uuid
from datetime import datetime, timezone

from app.core.redis_client import redis_client

logger = logging.getLogger(__name__)

ROOM_TTL = 86400  # 24 hours
MAX_MESSAGES = 200


class StaffChatService:
    """Ephemeral staff-customer chat backed by Redis only."""

    # ── Room lifecycle ────────────────────────────────────────────────

    async def create_room(
        self,
        *,
        request_id: str,
        user_id: str,
        user_name: str | None,
        staff_id: str,
        staff_name: str | None,
        venue_id: str | None = None,
        resource_label: str | None = None,
    ) -> None:
        room = {
            "request_id": request_id,
            "user_id": user_id,
            "user_name": user_name or "",
            "staff_id": staff_id,
            "staff_name": staff_name or "",
            "venue_id": venue_id or "",
            "resource_label": resource_label or "",
            "status": "active",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        await redis_client.set_json(
            f"staff_chat:room:{request_id}", room, ex=ROOM_TTL
        )
        await redis_client.delete(f"staff_chat:messages:{request_id}")
        logger.info("Staff chat room created: %s", request_id)

    async def get_room(self, request_id: str) -> dict | None:
        return await redis_client.get_json(f"staff_chat:room:{request_id}")

    async def close_room(self, request_id: str) -> None:
        room = await self.get_room(request_id)
        if not room:
            return
        room["status"] = "closed"
        await redis_client.set_json(
            f"staff_chat:room:{request_id}", room, ex=ROOM_TTL
        )
        logger.info("Staff chat room closed: %s", request_id)

    # ── Messages ──────────────────────────────────────────────────────

    async def send_message(
        self,
        room_id: str,
        sender_id: str,
        sender_name: str,
        sender_role: str,
        content: str,
    ) -> dict | None:
        room = await self.get_room(room_id)
        if not room or room["status"] != "active":
            return None

        if not self._is_participant(room, sender_id):
            return None

        msg = {
            "id": str(uuid.uuid4()),
            "room_id": room_id,
            "sender_id": sender_id,
            "sender_name": sender_name,
            "sender_role": sender_role,
            "content": content,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        key = f"staff_chat:messages:{room_id}"
        await redis_client.rpush(key, json.dumps(msg, ensure_ascii=False))
        await redis_client.ltrim(key, 0, MAX_MESSAGES - 1)
        await redis_client.expire(key, ROOM_TTL)
        await redis_client.set(f"staff_chat:room:{room_id}", json.dumps(room, ensure_ascii=False), ex=ROOM_TTL)

        return msg

    async def get_history(self, room_id: str, limit: int = 50) -> list[dict]:
        key = f"staff_chat:messages:{room_id}"
        try:
            raw_list = await redis_client.lrange(key, -limit, -1)
        except Exception:
            await redis_client.delete(key)
            return []
        messages = []
        for raw in raw_list:
            try:
                if isinstance(raw, str):
                    messages.append(json.loads(raw))
            except json.JSONDecodeError:
                continue
        return messages

    # ── Presence ──────────────────────────────────────────────────────

    async def set_online(self, room_id: str, user_id: str, online: bool = True) -> None:
        key = f"staff_chat:online:{room_id}:{user_id}"
        if online:
            await redis_client.set(key, "1", ex=60)
        else:
            await redis_client.delete(key)

    async def is_online(self, room_id: str, user_id: str) -> bool:
        return await redis_client.exists(f"staff_chat:online:{room_id}:{user_id}")

    async def refresh_presence(self, room_id: str, user_id: str) -> None:
        await redis_client.set(f"staff_chat:online:{room_id}:{user_id}", "1", ex=60)

    # ── Busy lock ─────────────────────────────────────────────────────

    async def set_busy(self, staff_id: str, room_id: str) -> None:
        await redis_client.set(f"staff_chat:staff_busy:{staff_id}", room_id)

    async def get_busy_room(self, staff_id: str) -> str | None:
        return await redis_client.get(f"staff_chat:staff_busy:{staff_id}")

    async def clear_busy(self, staff_id: str) -> None:
        await redis_client.delete(f"staff_chat:staff_busy:{staff_id}")

    # ── Call state ───────────────────────────────────────────────────

    CALL_TTL = 3600  # 1 hour max call duration

    async def set_call_state(
        self, room_id: str, state: str, caller_id: str, callee_id: str
    ) -> None:
        key = f"staff_chat:call:{room_id}"
        data = {
            "state": state,
            "caller_id": caller_id,
            "callee_id": callee_id,
            "started_at": datetime.now(timezone.utc).isoformat(),
        }
        await redis_client.set_json(key, data, ex=self.CALL_TTL)

    async def get_call_state(self, room_id: str) -> dict | None:
        return await redis_client.get_json(f"staff_chat:call:{room_id}")

    async def clear_call_state(self, room_id: str) -> None:
        await redis_client.delete(f"staff_chat:call:{room_id}")

    async def is_staff_in_call(self, staff_id: str) -> str | None:
        """Return the room_id where staff is currently in a call, or None."""
        keys = await redis_client.scan_keys("staff_chat:call:*")
        for key in keys:
            call = await redis_client.get_json(key)
            if call and call.get("state") == "connected":
                if call.get("caller_id") == staff_id or call.get("callee_id") == staff_id:
                    # Extract room_id from key "staff_chat:call:{room_id}"
                    return key.split("staff_chat:call:", 1)[1]
        return None

    # ── Helpers ───────────────────────────────────────────────────────

    async def list_rooms_for_staff(self, staff_id: str) -> list[dict]:
        """Return all rooms (active + closed) where this staff is a participant."""
        keys = await redis_client.scan_keys("staff_chat:room:*")
        rooms = []
        for key in keys:
            room = await redis_client.get_json(key)
            if room and room.get("staff_id") == staff_id:
                rooms.append(room)
        rooms.sort(key=lambda r: r.get("created_at", ""), reverse=True)
        return rooms

    async def list_active_rooms_for_staff(self, staff_id: str) -> list[dict]:
        """Return only active rooms for this staff."""
        all_rooms = await self.list_rooms_for_staff(staff_id)
        return [r for r in all_rooms if r.get("status") == "active"]

    @staticmethod
    def _is_participant(room: dict, user_id: str) -> bool:
        return user_id == room.get("user_id") or user_id == room.get("staff_id")


staff_chat_service = StaffChatService()
