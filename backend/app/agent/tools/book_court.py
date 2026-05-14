import json
import logging
from datetime import datetime

from langchain_core.tools import tool

from app.agent.context import current_user_id
from app.core.database import async_session_factory
from app.repositories.booking_repository import BookingRepository
from app.repositories.notification_repository import NotificationRepository
from app.services.booking_service import BookingService
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)


@tool
async def book_court(
    court_type: str,
    court_number: int,
    start_time: str,
    end_time: str,
    notes: str = "",
) -> str:
    """Đặt sân cho khách hàng. Kiểm tra tình trạng trống trước khi đặt.

    Args:
        court_type: Loại sân: billiards, pickleball, hoặc badminton
        court_number: Số sân (bắt đầu từ 1)
        start_time: Thời gian bắt đầu (ISO 8601, ví dụ: 2024-01-15T14:00:00)
        end_time: Thời gian kết thúc (ISO 8601, ví dụ: 2024-01-15T16:00:00)
        notes: Ghi chú thêm (tùy chọn)

    Returns:
        Kết quả đặt sân hoặc thông báo lỗi
    """
    try:
        start_dt = datetime.fromisoformat(start_time)
        end_dt = datetime.fromisoformat(end_time)
    except ValueError:
        return "Định dạng thời gian không hợp lệ. Vui lòng dùng ISO 8601 (ví dụ: 2024-01-15T14:00:00)."

    try:
        async with async_session_factory() as session:
            repo = BookingRepository(session)
            notification_service = NotificationService(NotificationRepository(session))
            service = BookingService(repo, notification_service)

            available = await service.check_availability(
                court_type=court_type,
                court_number=court_number,
                start_time=start_dt,
                end_time=end_dt,
            )

            if not available:
                # Find alternatives — which courts of the same type are free?
                alt_courts: list[int] = []
                for court_num in range(1, 9):
                    if court_num == court_number:
                        continue
                    is_free = await service.check_availability(
                        court_type=court_type,
                        court_number=court_num,
                        start_time=start_dt,
                        end_time=end_dt,
                    )
                    if is_free:
                        alt_courts.append(court_num)

                type_vi = COURT_TYPE_VIETNAMESE.get(court_type, court_type)

                if alt_courts:
                    courts_text = ", ".join(f"Sân {c}" for c in alt_courts[:4])
                    return (
                        f"❌ {type_vi} sân {court_number} đã có người đặt "
                        f"từ {start_dt.strftime('%H:%M')} đến {end_dt.strftime('%H:%M')} ngày {start_dt.strftime('%d/%m/%Y')}.\n"
                        f"Tuy nhiên, còn sân trống: {courts_text}.\n"
                        f"Bạn muốn đặt sân nào?"
                    )

                # All courts booked — suggest checking schedule for other times
                return (
                    f"❌ {type_vi} sân {court_number} đã có người đặt "
                    f"từ {start_dt.strftime('%H:%M')} đến {end_dt.strftime('%H:%M')} ngày {start_dt.strftime('%d/%m/%Y')}.\n"
                    f"Tất cả sân {type_vi} đều kín trong khung giờ này.\n"
                    f"Bạn có thể thử giờ khác hoặc hỏi mình để xem lịch trống."
                )

            from app.schemas.booking import BookingCreate

            data = BookingCreate(
                court_type=court_type,
                court_number=court_number,
                start_time=start_dt,
                end_time=end_dt,
                notes=notes,
            )
            booking = await service.create_booking(data, user_id=current_user_id.get())
            await session.commit()

            return (
                f"✅ Đặt sân thành công!\n"
                f"📍 Sân: {court_type} số {court_number}\n"
                f"🕐 Thời gian: {start_dt.strftime('%H:%M %d/%m/%Y')} - {end_dt.strftime('%H:%M %d/%m/%Y')}\n"
                f"📋 Mã đặt sân: {booking.id}\n"
                f"Trạng thái: {booking.status}"
            )

    except ValueError as exc:
        return f"❌ Không thể đặt sân: {exc}"
    except Exception as exc:
        logger.exception("Error in book_court tool")
        return f"❌ Lỗi hệ thống khi đặt sân: {exc}"
