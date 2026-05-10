import json
import logging
import uuid
from datetime import datetime, timezone

from langchain_core.tools import tool

from app.core.redis_client import redis_client
from app.services.notification_service import OPERATIONS_ROLES
from app.services.realtime import realtime_manager

logger = logging.getLogger(__name__)


@tool
async def call_staff(message: str, table_number: int = 0) -> str:
    """Gọi nhân viên hỗ trợ. Lưu thông báo vào Redis để nhân viên nhận được.

    Args:
        message: Nội dung yêu cầu hỗ trợ, ví dụ: "Cần thêm phấn bida", "Sân bị hư hỏng"
        table_number: Số bàn (0 nếu không áp dụng)

    Returns:
        Xác nhận đã gửi yêu cầu
    """
    try:
        notification_id = str(uuid.uuid4())
        timestamp = datetime.now(timezone.utc).isoformat()

        notification = {
            "id": notification_id,
            "event_type": "staff.requested",
            "title": "Khách cần hỗ trợ",
            "message": message,
            "target_roles": OPERATIONS_ROLES,
            "table_number": table_number,
            "status": "pending",
            "created_at": timestamp,
            "timestamp": timestamp,
            "source": "chatbot",
            "payload": {
                "table_number": table_number,
                "message": message,
            },
            "read_at": None,
        }

        await redis_client.set(
            f"staff_notification:{notification_id}",
            json.dumps(notification, ensure_ascii=False),
            ex=3600,
        )

        try:
            await realtime_manager.broadcast_to_roles(OPERATIONS_ROLES, notification)
            await redis_client.client.publish(
                "staff_notifications",
                json.dumps(notification, ensure_ascii=False),
            )
        except Exception:
            logger.warning(
                "Redis pub/sub publish failed, notification stored in key only"
            )

        logger.info(
            "Staff notification created: id=%s table=%d msg=%s",
            notification_id,
            table_number,
            message,
        )

        table_info = f" (bàn số {table_number})" if table_number > 0 else ""
        return (
            f"✅ Đã gọi nhân viên thành công!\n"
            f"📋 Mã yêu cầu: {notification_id}\n"
            f"📝 Nội dung: {message}{table_info}\n"
            f"⏳ Nhân viên sẽ đến hỗ trợ bạn shortly."
        )

    except Exception as exc:
        logger.exception("Error in call_staff tool")
        return f"❌ Lỗi khi gọi nhân viên: {exc}"
