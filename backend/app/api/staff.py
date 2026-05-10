from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.repositories.notification_repository import NotificationRepository
from app.schemas.notification import StaffNotifyRequest, StaffNotifyResponse
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/api/staff", tags=["staff"])


@router.post("/notify", response_model=StaffNotifyResponse, status_code=201)
async def notify_staff(
    request: StaffNotifyRequest,
    _: None = Depends(rate_limit(limit=10, window_seconds=60, scope="staff_notify")),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> StaffNotifyResponse:
    """Send a realtime notification to staff and managers."""
    service = NotificationService(NotificationRepository(session))
    notification = await service.notify_operations(
        event_type="staff.requested",
        title="Khách cần hỗ trợ",
        message=request.message,
        source="customer",
        payload={
            "user_id": str(user.id),
            "table_number": request.table_number,
            "message": request.message,
        },
    )
    timestamp = notification.created_at or datetime.now(timezone.utc)
    return StaffNotifyResponse(
        notification_id=notification.id,
        message=request.message,
        table_number=request.table_number,
        status="sent",
        timestamp=timestamp.isoformat(),
    )
