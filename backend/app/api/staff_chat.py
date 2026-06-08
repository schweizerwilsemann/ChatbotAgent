import json
import logging

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
)

from app.api.auth import get_current_user_from_token, get_current_user, require_roles
from app.core.database import async_session_factory
from app.models.user import User
from app.repositories.notification_repository import NotificationRepository
from app.schemas.staff_chat import StaffChatMessage
from app.services.notification_service import NotificationService
from app.services.realtime import realtime_manager
from app.services.staff_chat_service import staff_chat_service

router = APIRouter(prefix="/api/staff/chat", tags=["staff-chat"])

logger = logging.getLogger(__name__)

CHAT_NOTIFICATION_EVENT = "staff_chat_message"


def _role_of(user: User) -> str:
    value = user.role.value if hasattr(user.role, "value") else str(user.role)
    return "staff" if value in {"STAFF", "ADMIN"} else "customer"


def _preview_message(content: str, limit: int = 120) -> str:
    text = " ".join(content.split())
    if len(text) <= limit:
        return text
    return f"{text[:limit - 3]}..."


async def _send_ws(websocket: WebSocket, data: dict) -> None:
    try:
        await websocket.send_json(data)
    except Exception:
        pass


async def _notify_chat_recipient(
    *,
    room: dict,
    message: dict,
    sender_id: str,
    sender_name: str,
    sender_role: str,
) -> None:
    if sender_role == "staff":
        recipient_id = room.get("user_id")
        target_roles = ["CUSTOMER"]
        title = f"Tin nhắn từ {sender_name or 'nhân viên'}"
    else:
        recipient_id = room.get("staff_id")
        target_roles = ["STAFF", "ADMIN"]
        title = f"Tin nhắn từ {sender_name or 'khách hàng'}"

    if not recipient_id:
        return

    if sender_role == "staff":
        try:
            if await staff_chat_service.is_online(message["room_id"], recipient_id):
                return
        except Exception:
            logger.debug("Could not check staff chat recipient presence", exc_info=True)

    payload = {
        "request_id": message["room_id"],
        "room_id": message["room_id"],
        "message_id": message["id"],
        "sender_id": sender_id,
        "sender_name": sender_name,
        "sender_role": sender_role,
        "content": message["content"],
        "chat_route": (
            f"/staff-chat/{message['room_id']}"
            if sender_role == "staff"
            else f"/staff-operator-chat/{message['room_id']}"
        ),
    }

    try:
        async with async_session_factory() as session:
            service = NotificationService(NotificationRepository(session))
            await service.notify_user(
                event_type=CHAT_NOTIFICATION_EVENT,
                title=title,
                message=_preview_message(message["content"]),
                target_roles=target_roles,
                source="staff_chat",
                target_user_id=recipient_id,
                payload=payload,
            )
            await session.commit()
    except Exception:
        logger.warning("Staff chat notification skipped", exc_info=True)


# ── REST: History ─────────────────────────────────────────────────────


@router.get("/rooms")
async def list_my_chat_rooms(
    user: User = Depends(require_roles("STAFF", "ADMIN")),
) -> list[dict]:
    staff_id = str(user.id)
    rooms = await staff_chat_service.list_rooms_for_staff(staff_id)
    result = []
    for room in rooms:
        last_msgs = await staff_chat_service.get_history(room["request_id"], limit=1)
        last_msg = last_msgs[0] if last_msgs else None
        result.append({
            **room,
            "last_message": last_msg,
        })
    return result


@router.get("/{request_id}/history", response_model=list[StaffChatMessage])
async def get_chat_history(
    request_id: str,
    limit: int = Query(50, ge=1, le=200),
    user: User = Depends(get_current_user),
) -> list[StaffChatMessage]:
    room = await staff_chat_service.get_room(request_id)
    if not room:
        raise HTTPException(status_code=404, detail="Chat room not found")

    user_id = str(user.id)
    if user_id != room.get("user_id") and user_id != room.get("staff_id"):
        raise HTTPException(status_code=403, detail="Not a participant")

    messages = await staff_chat_service.get_history(request_id, limit=limit)
    return [StaffChatMessage(**m) for m in messages]


# ── REST: Call availability ───────────────────────────────────────────


@router.get("/{request_id}/call/availability")
async def check_call_availability(
    request_id: str,
    user: User = Depends(get_current_user),
) -> dict:
    room = await staff_chat_service.get_room(request_id)
    if not room:
        raise HTTPException(status_code=404, detail="Chat room not found")

    user_id = str(user.id)
    if user_id != room.get("user_id") and user_id != room.get("staff_id"):
        raise HTTPException(status_code=403, detail="Not a participant")

    staff_id = room.get("staff_id", "")
    existing_call_room = await staff_chat_service.is_staff_in_call(staff_id)
    is_available = existing_call_room is None or existing_call_room == request_id

    current_call = await staff_chat_service.get_call_state(request_id)

    return {
        "available": is_available,
        "current_call": current_call,
    }


# ── REST: Close room ──────────────────────────────────────────────────


@router.post("/{request_id}/close")
async def close_chat_room(
    request_id: str,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
) -> dict:
    room = await staff_chat_service.get_room(request_id)
    if not room:
        raise HTTPException(status_code=404, detail="Chat room not found")

    await staff_chat_service.close_room(request_id)
    # Notify both sides via WS
    await realtime_manager.broadcast_to_room(request_id, {
        "type": "room_closed",
        "room_id": request_id,
    })

    return {"status": "closed"}


# ── WebSocket: Bidirectional chat ─────────────────────────────────────


@router.websocket("/{request_id}/ws")
async def chat_websocket(
    websocket: WebSocket,
    request_id: str,
    token: str = Query(...),
) -> None:
    # ── Auth ──────────────────────────────────────────────────────
    try:
        async with async_session_factory() as session:
            user = await get_current_user_from_token(token, session)
            if user is None:
                await websocket.close(code=1008)
                return
    except Exception:
        logger.exception("Staff chat WS auth failed")
        try:
            await websocket.close(code=1011)
        except Exception:
            pass
        return

    user_id = str(user.id)
    user_name = user.name or ""
    role = _role_of(user)

    # ── Validate room ─────────────────────────────────────────────
    room = await staff_chat_service.get_room(request_id)
    if not room:
        await websocket.close(code=4004, reason="Room not found")
        return

    if user_id != room.get("user_id") and user_id != room.get("staff_id"):
        await websocket.close(code=4003, reason="Not a participant")
        return

    if room.get("status") == "closed":
        await websocket.close(code=4010, reason="Room is closed")
        return

    # ── Connect ───────────────────────────────────────────────────
    await realtime_manager.connect_to_room(websocket, request_id, user_id)
    await staff_chat_service.set_online(request_id, user_id, online=True)

    # Notify room that participant joined
    await realtime_manager.broadcast_to_room(request_id, {
        "type": "participant_joined",
        "room_id": request_id,
        "user_id": user_id,
        "user_name": user_name,
        "role": role,
    })

    # ── Message loop ──────────────────────────────────────────────
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = data.get("type", "message")

            if msg_type == "message":
                content = data.get("content", "").strip()
                if not content:
                    continue

                msg = await staff_chat_service.send_message(
                    room_id=request_id,
                    sender_id=user_id,
                    sender_name=user_name,
                    sender_role=role,
                    content=content,
                )
                if msg:
                    await realtime_manager.broadcast_to_room(request_id, {
                        "type": "message",
                        **msg,
                    })
                    await _notify_chat_recipient(
                        room=room,
                        message=msg,
                        sender_id=user_id,
                        sender_name=user_name,
                        sender_role=role,
                    )

            elif msg_type == "typing":
                await realtime_manager.broadcast_to_room(
                    request_id,
                    {
                        "type": "typing",
                        "room_id": request_id,
                        "user_id": user_id,
                        "role": role,
                    },
                    exclude=websocket,
                )

            elif msg_type == "ping":
                await staff_chat_service.refresh_presence(request_id, user_id)

            # ── Call signaling ───────────────────────────────────────

            elif msg_type == "call_offer":
                # Customer or staff initiates a call
                callee_id = data.get("callee_id", "")
                sdp = data.get("sdp", "")

                # Check if callee (staff) is busy on another call
                if role == "customer":
                    busy_room = await staff_chat_service.is_staff_in_call(
                        room.get("staff_id", "")
                    )
                    if busy_room and busy_room != request_id:
                        await _send_ws(websocket, {
                            "type": "call_busy",
                            "room_id": request_id,
                            "reason": "Staff đang bận cuộc gọi khác",
                        })
                        continue

                await staff_chat_service.set_call_state(
                    request_id, "ringing", user_id, callee_id
                )
                await realtime_manager.broadcast_to_room(
                    request_id,
                    {
                        "type": "call_offer",
                        "room_id": request_id,
                        "caller_id": user_id,
                        "caller_name": user_name,
                        "caller_role": role,
                        "callee_id": callee_id,
                        "sdp": sdp,
                    },
                    exclude=websocket,
                )

            elif msg_type == "call_answer":
                sdp = data.get("sdp", "")
                call = await staff_chat_service.get_call_state(request_id)
                if call:
                    await staff_chat_service.set_call_state(
                        request_id, "connected", call["caller_id"], call["callee_id"]
                    )
                    # Set staff busy lock
                    staff_id_in_call = room.get("staff_id", "")
                    if staff_id_in_call:
                        await staff_chat_service.set_busy(staff_id_in_call, request_id)

                await realtime_manager.broadcast_to_room(
                    request_id,
                    {
                        "type": "call_answer",
                        "room_id": request_id,
                        "user_id": user_id,
                        "sdp": sdp,
                    },
                    exclude=websocket,
                )

            elif msg_type == "call_ice_candidate":
                candidate = data.get("candidate", {})
                await realtime_manager.broadcast_to_room(
                    request_id,
                    {
                        "type": "call_ice_candidate",
                        "room_id": request_id,
                        "user_id": user_id,
                        "candidate": candidate,
                    },
                    exclude=websocket,
                )

            elif msg_type == "call_end":
                call = await staff_chat_service.get_call_state(request_id)
                if call:
                    # Clear staff busy lock
                    staff_id_in_call = room.get("staff_id", "")
                    if staff_id_in_call:
                        await staff_chat_service.clear_busy(staff_id_in_call)
                await staff_chat_service.clear_call_state(request_id)
                await realtime_manager.broadcast_to_room(
                    request_id,
                    {
                        "type": "call_end",
                        "room_id": request_id,
                        "user_id": user_id,
                        "reason": data.get("reason", "ended"),
                    },
                )

            elif msg_type == "call_reject":
                await staff_chat_service.clear_call_state(request_id)
                await realtime_manager.broadcast_to_room(
                    request_id,
                    {
                        "type": "call_reject",
                        "room_id": request_id,
                        "user_id": user_id,
                        "reason": data.get("reason", "rejected"),
                    },
                    exclude=websocket,
                )

    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("Staff chat WS error for room %s", request_id)
    finally:
        # ── Cleanup ───────────────────────────────────────────────
        realtime_manager.disconnect_from_room(websocket, request_id)
        await staff_chat_service.set_online(request_id, user_id, online=False)

        if role == "staff":
            await staff_chat_service.clear_busy(user_id)

        await realtime_manager.broadcast_to_room(request_id, {
            "type": "participant_left",
            "room_id": request_id,
            "user_id": user_id,
            "role": role,
        })
