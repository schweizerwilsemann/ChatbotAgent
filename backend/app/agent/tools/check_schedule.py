import logging
from datetime import datetime

from langchain_core.tools import tool

from app.core.database import async_session_factory
from app.repositories.booking_repository import BookingRepository

logger = logging.getLogger(__name__)

COURT_TYPE_VIETNAMESE = {
    "billiards": "Bida",
    "pickleball": "Pickleball",
    "badminton": "Cầu lông",
}


@tool
async def check_schedule(date: str, court_type: str = "") -> str:
    """Kiểm tra lịch đặt sân cho một ngày cụ thể.

    Args:
        date: Ngày cần kiểm tra (định dạng YYYY-MM-DD, ví dụ: 2024-01-15)
        court_type: Loại sân cần kiểm tra (tùy chọn): billiards, pickleball, hoặc badminton. Để trống sẽ hiển thị tất cả.

    Returns:
        Lịch đặt sân dạng văn bản
    """
    try:
        check_date = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        return "❌ Định dạng ngày không hợp lệ. Vui lòng dùng YYYY-MM-DD (ví dụ: 2024-01-15)."

    if court_type and court_type.lower() not in COURT_TYPE_VIETNAMESE:
        return f"❌ Loại sân không hợp lệ: {court_type}. Chọn: billiards, pickleball, hoặc badminton."

    try:
        async with async_session_factory() as session:
            repo = BookingRepository(session)
            bookings = await repo.get_schedule(
                date=check_date,
                court_type=court_type.lower() if court_type else "",
            )

        if not bookings:
            type_text = (
                f" {COURT_TYPE_VIETNAMESE.get(court_type.lower(), court_type)}"
                if court_type
                else ""
            )
            return (
                f"📅 Lịch đặt sân{type_text} ngày {check_date.strftime('%d/%m/%Y')}:\n"
                f"Không có đặt sân nào. Tất cả các sân đều trống!"
            )

        schedule_lines = []
        current_type = None
        for booking in bookings:
            if booking.court_type != current_type:
                current_type = booking.court_type
                type_name = COURT_TYPE_VIETNAMESE.get(current_type, current_type)
                schedule_lines.append(f"\n🏆 **{type_name}**:")

            start = booking.start_time.strftime("%H:%M")
            end = booking.end_time.strftime("%H:%M")
            schedule_lines.append(
                f"  Sân {booking.court_number}: {start} - {end} ({booking.status})"
            )

        return f"📅 Lịch đặt sân ngày {check_date.strftime('%d/%m/%Y')}:\n" + "\n".join(
            schedule_lines
        )

    except Exception as exc:
        logger.exception("Error in check_schedule tool")
        return f"❌ Lỗi khi kiểm tra lịch: {exc}"
