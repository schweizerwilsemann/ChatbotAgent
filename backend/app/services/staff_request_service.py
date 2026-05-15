import logging
from datetime import datetime, timezone

from app.repositories.notification_repository import NotificationRepository
from app.repositories.staff_request_repository import StaffRequestRepository
from app.schemas.notification import NotificationResponse
from app.schemas.staff_request import StaffRequestResponse
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)

REQUEST_TYPE_LABELS = {
    "order": "Gọi đồ uống / thức ăn",
    "payment": "Thanh toán",
    "help": "Hỗ trợ chung",
    "maintenance": "Sự cố kỹ thuật",
    "other": "Yêu cầu khác",
}


class StaffRequestService:
    def __init__(
        self,
        repo: StaffRequestRepository,
        notification_service: NotificationService,
    ) -> None:
        self._repo = repo
        self._notification_service = notification_service

    async def create_request(
        self,
        *,
        user_id: str,
        user_name: str | None,
        request_type: str,
        description: str | None,
        table_number: int | None,
    ) -> StaffRequestResponse:
        request = await self._repo.create(
            user_id=user_id,
            user_name=user_name,
            request_type=request_type,
            description=description,
            table_number=table_number,
        )

        type_label = REQUEST_TYPE_LABELS.get(request_type, request_type)
        title = f"Khách gọi nhân viên — {type_label}"
        parts = []
        if user_name:
            parts.append(f"Khách: {user_name}")
        if table_number and table_number > 0:
            parts.append(f"Bàn: {table_number}")
        if description:
            parts.append(f"Yêu cầu: {description}")
        message = " | ".join(parts) if parts else f"Yêu cầu: {type_label}"

        await self._notification_service.notify_operations(
            event_type="staff_request",
            title=title,
            message=message,
            source="customer",
            payload={
                "request_id": str(request.id),
                "user_id": user_id,
                "user_name": user_name or "",
                "request_type": request_type,
                "description": description or "",
                "table_number": table_number or 0,
                "status": "pending",
            },
        )

        return self.to_response(request)

    async def get_pending_requests(self) -> list[StaffRequestResponse]:
        requests = await self._repo.get_pending()
        return [self.to_response(r) for r in requests]

    async def get_user_requests(self, user_id: str) -> list[StaffRequestResponse]:
        requests = await self._repo.get_by_user(user_id)
        return [self.to_response(r) for r in requests]

    async def get_active_user_request(
        self, user_id: str
    ) -> StaffRequestResponse | None:
        request = await self._repo.get_active_by_user(user_id)
        return self.to_response(request) if request else None

    async def accept_request(
        self, request_id: str, staff_id: str, staff_name: str | None
    ) -> StaffRequestResponse:
        request = await self._repo.accept(request_id, staff_id, staff_name)
        if not request:
            raise ValueError("Request not found or not in pending status")

        await self._notification_service.notify_operations(
            event_type="staff_request_accepted",
            title="Yêu cầu đã được tiếp nhận",
            message=f"{staff_name or 'Nhân viên'} đã tiếp nhận yêu cầu",
            source="staff",
            payload={
                "request_id": str(request.id),
                "user_id": request.user_id,
                "accepted_by": staff_id,
                "accepted_by_name": staff_name or "",
                "status": "accepted",
            },
        )

        return self.to_response(request)

    async def complete_request(self, request_id: str) -> StaffRequestResponse:
        request = await self._repo.complete(request_id)
        if not request:
            raise ValueError("Request not found or not in accepted status")
        return self.to_response(request)

    async def cancel_request(self, request_id: str) -> StaffRequestResponse:
        request = await self._repo.cancel(request_id)
        if not request:
            raise ValueError("Request not found or cannot be cancelled")
        return self.to_response(request)

    @staticmethod
    def to_response(request) -> StaffRequestResponse:
        return StaffRequestResponse(
            id=str(request.id),
            user_id=request.user_id,
            user_name=request.user_name,
            request_type=request.request_type,
            description=request.description,
            table_number=request.table_number,
            status=request.status,
            accepted_by=request.accepted_by,
            accepted_by_name=request.accepted_by_name,
            created_at=getattr(request, "created_at", None)
            or datetime.now(timezone.utc),
            accepted_at=request.accepted_at,
            completed_at=request.completed_at,
        )
