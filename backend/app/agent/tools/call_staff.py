import logging
import uuid

from langchain_core.tools import tool

from app.agent.context import current_user_id
from app.core.database import async_session_factory
from app.repositories.notification_repository import NotificationRepository
from app.repositories.staff_request_repository import StaffRequestRepository
from app.schemas.staff_request import StaffRequestCreate
from app.services.notification_service import NotificationService
from app.services.staff_request_service import StaffRequestService

logger = logging.getLogger(__name__)

REQUEST_TYPE_MAP = {
    "đồ uống": "order",
    "đồ ăn": "order",
    "thức ăn": "order",
    "order": "order",
    "gọi món": "order",
    "thanh toán": "payment",
    "tính tiền": "payment",
    "trả tiền": "payment",
    "payment": "payment",
    "hỗ trợ": "help",
    "giúp đỡ": "help",
    "help": "help",
    "sự cố": "maintenance",
    "hư": "maintenance",
    "hỏng": "maintenance",
    "maintenance": "maintenance",
}


@tool
async def call_staff(message: str, table_number: int = 0, request_type: str = "help") -> str:
    """Gọi nhân viên hỗ trợ tại quán. Tạo yêu cầu trong hệ thống để nhân viên nhận và xử lý.

    Args:
        message: Mô tả yêu cầu, ví dụ: "Cần thêm phấn bida", "Sân bị hư hỏng", "Muốn thanh toán"
        table_number: Số bàn hoặc sân (0 nếu không áp dụng)
        request_type: Loại yêu cầu — một trong: "order" (đồ ăn/uống), "payment" (thanh toán), "help" (hỗ trợ chung), "maintenance" (sự cố kỹ thuật), "other" (khác)

    Returns:
        Xác nhận đã gửi yêu cầu đến nhân viên
    """
    try:
        user_uuid = current_user_id.get()
        if not user_uuid:
            return "❌ Không xác định được khách hàng. Vui lòng thử lại."

        # Normalize request_type from Vietnamese
        normalized_type = REQUEST_TYPE_MAP.get(request_type.lower().strip(), None)
        if normalized_type is None:
            # Try to infer from message content
            msg_lower = message.lower()
            for keyword, rtype in REQUEST_TYPE_MAP.items():
                if keyword in msg_lower:
                    normalized_type = rtype
                    break
            if normalized_type is None:
                normalized_type = "other"

        async with async_session_factory() as session:
            service = StaffRequestService(
                repo=StaffRequestRepository(session),
                notification_service=NotificationService(
                    NotificationRepository(session)
                ),
            )

            try:
                result = await service.create_request(
                    user_id=str(user_uuid),
                    user_name=None,
                    request_type=normalized_type,
                    description=message,
                    table_number=table_number if table_number > 0 else None,
                )
                await session.commit()
            except Exception:
                # Fallback: if DB fails, still notify via notification service
                logger.warning("StaffRequest DB create failed, using notification-only fallback", exc_info=True)
                notif_service = NotificationService(NotificationRepository(session))
                await notif_service.notify_operations(
                    event_type="staff.requested",
                    title="Khách cần hỗ trợ",
                    message=message,
                    source="chatbot",
                    payload={
                        "user_id": str(user_uuid),
                        "table_number": table_number,
                        "message": message,
                    },
                )
                await session.commit()
                table_info = f" (bàn số {table_number})" if table_number > 0 else ""
                return (
                    f"✅ Đã gọi nhân viên thành công!\n"
                    f"📝 Nội dung: {message}{table_info}\n"
                    f"⏳ Nhân viên sẽ đến hỗ trợ bạn ngay."
                )

        table_info = f" (bàn số {table_number})" if table_number > 0 else ""
        return (
            f"✅ Đã gọi nhân viên thành công!\n"
            f"📋 Mã yêu cầu: {result.id}\n"
            f"📝 Nội dung: {message}{table_info}\n"
            f"⏳ Nhân viên sẽ đến hỗ trợ bạn ngay."
        )

    except Exception as exc:
        logger.exception("Error in call_staff tool")
        return f"❌ Lỗi khi gọi nhân viên: {exc}"
