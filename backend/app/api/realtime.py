from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user_from_token, require_roles
from app.core.database import async_session_factory, get_db
from app.models.user import UserRole
from app.repositories.notification_repository import NotificationRepository
from app.schemas.notification import NotificationResponse
from app.services.notification_service import NotificationService
from app.services.realtime import realtime_manager

router = APIRouter(prefix="/api/realtime", tags=["realtime"])


def _is_operations_role(role: UserRole | str) -> bool:
    value = role.value if isinstance(role, UserRole) else str(role)
    return value in {"STAFF", "ADMIN"}


@router.websocket("/notifications")
async def staff_notifications_socket(
    websocket: WebSocket,
    token: str = Query(...),
) -> None:
    async with async_session_factory() as session:
        user = await get_current_user_from_token(token, session)
        if user is None or not _is_operations_role(user.role):
            await websocket.close(code=1008)
            return
        role = user.role.value if isinstance(user.role, UserRole) else str(user.role)

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
