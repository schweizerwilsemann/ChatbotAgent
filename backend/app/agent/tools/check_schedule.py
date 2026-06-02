import logging
from datetime import datetime
from zoneinfo import ZoneInfo

from langchain_core.tools import tool

from app.agent.context import current_chat_context
from app.core.config import settings
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
        date: Ngày cần kiểm tra (định dạng YYYY-MM-DD)
        court_type: Loại sân cần kiểm tra (tùy chọn): billiards,
            pickleball, hoặc badminton. Để trống sẽ hiển thị tất cả.

    Returns:
        Lịch đặt sân dạng văn bản
    """
    try:
        check_date = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        return "❌ Định dạng ngày không hợp lệ. Vui lòng dùng YYYY-MM-DD."

    chat_context = current_chat_context.get() or {}
    selected_venue_id = chat_context.get("venue_id")
    selected_venue_name = chat_context.get("venue_name")
    normalized_court_type = (court_type or chat_context.get("court_type") or "").lower()

    if normalized_court_type and normalized_court_type not in COURT_TYPE_VIETNAMESE:
        return (
            f"❌ Loại sân không hợp lệ: {normalized_court_type}. "
            "Chọn: billiards, pickleball, hoặc badminton."
        )

    try:
        async with async_session_factory() as session:
            repo = BookingRepository(session)
            bookings = await repo.get_schedule(
                date=check_date,
                court_type=normalized_court_type,
                venue_id=selected_venue_id,
            )

        if not bookings:
            type_text = (
                f" {COURT_TYPE_VIETNAMESE.get(normalized_court_type, normalized_court_type)}"
                if normalized_court_type
                else ""
            )
            venue_text = f" tại {selected_venue_name}" if selected_venue_name else ""
            return (
                f"📅 Lịch đặt sân{type_text}{venue_text} ngày {check_date.strftime('%d/%m/%Y')}:\n"
                f"Không có đặt sân nào. Tất cả các sân đều trống!"
            )

        schedule_lines = []
        current_type = None
        for booking in bookings:
            if booking.court_type != current_type:
                current_type = booking.court_type
                type_name = COURT_TYPE_VIETNAMESE.get(current_type, current_type)
                schedule_lines.append(f"\n🏆 **{type_name}**:")

            local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
            start_local = booking.start_time.astimezone(local_tz) if booking.start_time.tzinfo else booking.start_time
            end_local = booking.end_time.astimezone(local_tz) if booking.end_time.tzinfo else booking.end_time
            start = start_local.strftime("%H:%M")
            end = end_local.strftime("%H:%M")
            schedule_lines.append(
                f"  Sân {booking.court_number}: {start} - {end} ({booking.status})"
            )

        venue_text = f" tại {selected_venue_name}" if selected_venue_name else ""
        return (
            f"📅 Lịch đặt sân{venue_text} ngày {check_date.strftime('%d/%m/%Y')}:\n"
            + "\n".join(schedule_lines)
        )

    except Exception as exc:
        logger.exception("Error in check_schedule tool")
        return f"❌ Lỗi khi kiểm tra lịch: {exc}"
