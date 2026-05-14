import logging

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user_from_token, require_roles
from app.core.database import async_session_factory, get_db
from app.models.user import UserRole
from app.repositories.notification_repository import NotificationRepository
from app.schemas.notification import NotificationResponse
from app.services.notification_service import NotificationService
from app.services.realtime import realtime_manager

router = APIRouter(prefix="/api/realtime", tags=["realtime"])

logger = logging.getLogger(__name__)


def _is_operations_role(role: UserRole | str) -> bool:
    value = role.value if isinstance(role, UserRole) else str(role)
    return value in {"STAFF", "ADMIN"}


@router.websocket("/notifications")
async def staff_notifications_socket(
    websocket: WebSocket,
    token: str = Query(...),
) -> None:
    try:
        async with async_session_factory() as session:
            user = await get_current_user_from_token(token, session)
            if user is None or not _is_operations_role(user.role):
                await websocket.close(code=1008)
                return
            role = (
                user.role.value if isinstance(user.role, UserRole) else str(user.role)
            )
    except Exception:
        logger.exception("WebSocket auth failed")
        try:
            await websocket.close(code=1011)
        except Exception:
            pass
        return

    await realtime_manager.connect(websocket, role)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        realtime_manager.disconnect(websocket, role)
    except Exception:
        realtime_manager.disconnect(websocket, role)


@router.get("/notifications", response_model=list[NotificationResponse])
async def list_notifications(
    limit: int = Query(50, ge=1, le=100),
    _=Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[NotificationResponse]:
    service = NotificationService(NotificationRepository(session))
    return await service.list_for_operations(limit=limit)


@router.patch("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    _=Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> dict:
    """Mark a single notification as read."""
    repo = NotificationRepository(session)
    notification = await repo.mark_as_read(notification_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    await session.commit()
    return {"id": str(notification.id), "read_at": notification.read_at.isoformat()}


@router.patch("/notifications/read-all")
async def mark_all_notifications_read(
    user=Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> dict:
    """Mark all unread notifications as read for the current user's role."""
    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    repo = NotificationRepository(session)
    count = await repo.mark_all_as_read([role_value])
    await session.commit()
    return {"marked": count}
