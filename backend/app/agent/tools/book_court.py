import logging
import unicodedata
from datetime import datetime

from langchain_core.tools import tool

from app.agent.context import current_chat_context, current_user_id
from app.core.database import async_session_factory
from app.repositories.booking_repository import BookingRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.venue_repository import VenueRepository
from app.services.booking_service import BookingService
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)

COURT_TYPE_VIETNAMESE = {
    "billiards": "Bida",
    "pickleball": "Pickleball",
    "badminton": "Cầu lông",
}

COURT_TYPE_ALIASES = {
    "billiards": "billiards",
    "billiard": "billiards",
    "bida": "billiards",
    "bi da": "billiards",
    "pool": "billiards",
    "pickleball": "pickleball",
    "badminton": "badminton",
    "cau long": "badminton",
}

RESOURCE_TYPE_TO_COURT_TYPE = {
    "ResourceType.BILLIARDS_TABLE": "billiards",
    "billiards_table": "billiards",
    "ResourceType.PICKLEBALL_COURT": "pickleball",
    "pickleball_court": "pickleball",
    "ResourceType.BADMINTON_COURT": "badminton",
    "badminton_court": "badminton",
}


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
        court_type: Loại sân: billiards, pickleball, hoặc badminton.
            Nếu venue đang chọn chỉ có một loại sân, dùng loại đó.
        court_number: Số sân/bàn (bắt đầu từ 1)
        start_time: Thời gian bắt đầu (ISO 8601, ví dụ: YYYY-MM-DDT14:00:00)
        end_time: Thời gian kết thúc (ISO 8601, ví dụ: YYYY-MM-DDT16:00:00)
        notes: Ghi chú thêm (tùy chọn)

    Returns:
        Kết quả đặt sân hoặc thông báo lỗi
    """
    chat_context = current_chat_context.get() or {}
    selected_venue_id = _optional_str(chat_context.get("venue_id"))
    selected_venue_name = _optional_str(chat_context.get("venue_name"))
    normalized_court_type = _normalize_court_type(
        court_type or _optional_str(chat_context.get("court_type")) or ""
    )

    if not normalized_court_type:
        available = chat_context.get("available_court_type_names") or []
        if available:
            return (
                "Mình chưa xác định được loại sân cần đặt. "
                f"Venue đang chọn có: {', '.join(map(str, available))}."
            )
        return "Bạn muốn đặt sân loại nào: bida, pickleball hay cầu lông?"

    try:
        start_dt = datetime.fromisoformat(start_time)
        end_dt = datetime.fromisoformat(end_time)
    except ValueError:
        return (
            "Định dạng thời gian không hợp lệ. Vui lòng dùng ISO 8601 "
            "(ví dụ: YYYY-MM-DDT14:00:00)."
        )

    try:
        async with async_session_factory() as session:
            repo = BookingRepository(session)
            venue_repo = VenueRepository(session)
            notification_service = NotificationService(
                NotificationRepository(session),
                venue_repo,
            )
            service = BookingService(repo, notification_service, venue_repo)

            candidates = await _resource_candidates(
                venue_repo=venue_repo,
                venue_id=selected_venue_id,
                court_type=normalized_court_type,
            )
            if selected_venue_id and not candidates:
                available = chat_context.get("available_court_type_names") or []
                type_vi = COURT_TYPE_VIETNAMESE.get(
                    normalized_court_type,
                    normalized_court_type,
                )
                venue_text = f" tại {selected_venue_name}" if selected_venue_name else ""
                available_text = (
                    f" Venue này hiện có: {', '.join(map(str, available))}."
                    if available
                    else ""
                )
                return f"❌ Không có {type_vi}{venue_text}.{available_text}"

            resource_id = None
            resource_label = None
            if candidates:
                resource_id, resource_label = candidates.get(court_number, (None, None))
                if selected_venue_id and not resource_id:
                    kind = _resource_kind(normalized_court_type)
                    available_numbers = ", ".join(
                        str(number) for number in sorted(candidates)
                    )
                    venue_text = f" tại {selected_venue_name}" if selected_venue_name else ""
                    return (
                        f"❌ Không tìm thấy {kind} số {court_number}{venue_text}."
                        + (
                            f" Hiện có {kind} số: {available_numbers}."
                            if available_numbers
                            else ""
                        )
                    )

            available = await service.check_availability(
                court_type=normalized_court_type,
                court_number=court_number,
                start_time=start_dt,
                end_time=end_dt,
                resource_id=resource_id,
            )

            if not available:
                alt_courts = []
                for court_num, (candidate_resource_id, _) in candidates.items():
                    if court_num == court_number:
                        continue
                    is_free = await service.check_availability(
                        court_type=normalized_court_type,
                        court_number=court_num,
                        start_time=start_dt,
                        end_time=end_dt,
                        resource_id=candidate_resource_id,
                    )
                    if is_free:
                        alt_courts.append(court_num)

                if not candidates:
                    for court_num in range(1, 9):
                        if court_num == court_number:
                            continue
                        is_free = await service.check_availability(
                            court_type=normalized_court_type,
                            court_number=court_num,
                            start_time=start_dt,
                            end_time=end_dt,
                        )
                        if is_free:
                            alt_courts.append(court_num)

                type_vi = COURT_TYPE_VIETNAMESE.get(
                    normalized_court_type,
                    normalized_court_type,
                )
                kind = _resource_kind(normalized_court_type)

                if alt_courts:
                    resource_text = ", ".join(
                        f"{_resource_kind_title(normalized_court_type)} {number}"
                        for number in alt_courts[:4]
                    )
                    return (
                        f"❌ {type_vi} {kind} {court_number} đã có người đặt "
                        f"từ {start_dt.strftime('%H:%M')} "
                        f"đến {end_dt.strftime('%H:%M')} "
                        f"ngày {start_dt.strftime('%d/%m/%Y')}.\n"
                        f"Tuy nhiên, còn trống: {resource_text}.\n"
                        f"Bạn muốn đặt {kind} nào?"
                    )

                return (
                    f"❌ {type_vi} {kind} {court_number} đã có người đặt "
                    f"từ {start_dt.strftime('%H:%M')} "
                    f"đến {end_dt.strftime('%H:%M')} "
                    f"ngày {start_dt.strftime('%d/%m/%Y')}.\n"
                    f"Tất cả {kind} {type_vi} đều kín trong khung giờ này.\n"
                    f"Bạn có thể thử giờ khác hoặc hỏi mình để xem lịch trống."
                )

            from app.schemas.booking import BookingCreate

            data = BookingCreate(
                venue_id=selected_venue_id,
                resource_id=resource_id,
                resource_label=resource_label,
                court_type=normalized_court_type,
                court_number=court_number,
                start_time=start_dt,
                end_time=end_dt,
                notes=notes,
            )
            booking = await service.create_booking(data, user_id=current_user_id.get())
            await session.commit()

            display_label = (
                booking.resource_label
                or f"{COURT_TYPE_VIETNAMESE.get(normalized_court_type, normalized_court_type)} "
                f"{_resource_kind(normalized_court_type)} số {booking.court_number}"
            )
            venue_text = f"\n📍 Quán: {selected_venue_name}" if selected_venue_name else ""

            # Set structured metadata for the chat UI
            chat_context["order_metadata"] = {
                "type": "booking",
                "id": str(booking.id),
                "label": display_label,
                "court_type": normalized_court_type,
                "court_number": booking.court_number,
                "time": (
                    f"{start_dt.strftime('%H:%M')} - "
                    f"{end_dt.strftime('%H:%M')} {start_dt.strftime('%d/%m/%Y')}"
                ),
                "total_price": booking.total_price or 0,
                "payment_status": booking.payment_status or "unpaid",
                "venue_name": selected_venue_name or "",
                "customer_name": chat_context.get("user_name", ""),
                "customer_phone": chat_context.get("user_phone", ""),
            }

            return (
                f"✅ Đặt sân thành công!{venue_text}\n"
                f"📍 Sân/Bàn: {display_label}\n"
                f"🕐 Thời gian: {start_dt.strftime('%H:%M %d/%m/%Y')} - "
                f"{end_dt.strftime('%H:%M %d/%m/%Y')}\n"
                f"📋 Mã đặt sân: {booking.id}\n"
                f"Trạng thái: {booking.status}"
            )

    except ValueError as exc:
        return f"❌ Không thể đặt sân: {exc}"
    except Exception as exc:
        logger.exception("Error in book_court tool")
        return f"❌ Lỗi hệ thống khi đặt sân: {exc}"


async def _resource_candidates(
    *,
    venue_repo: VenueRepository,
    venue_id: str | None,
    court_type: str,
) -> dict[int, tuple[str | None, str | None]]:
    if not venue_id:
        return {}

    rows = await venue_repo.list_resources(venue_id=venue_id, status="active")
    candidates: dict[int, tuple[str | None, str | None]] = {}
    for row in rows:
        resource = row["resource"]
        if _court_type_from_resource(resource) != court_type:
            continue
        candidates[resource.number] = (str(resource.id), resource.name)
    return candidates


def _court_type_from_resource(resource) -> str | None:
    sport_type = (getattr(resource, "sport_type", "") or "").lower()
    if sport_type in COURT_TYPE_VIETNAMESE:
        return sport_type

    resource_type = getattr(resource, "resource_type", "")
    resource_type_value = (
        resource_type.value if hasattr(resource_type, "value") else str(resource_type)
    )
    return RESOURCE_TYPE_TO_COURT_TYPE.get(resource_type_value)


def _normalize_court_type(value: str) -> str:
    normalized = _strip_diacritics(value).lower().strip()
    return COURT_TYPE_ALIASES.get(normalized, normalized)


def _strip_diacritics(text: str) -> str:
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(char for char in nfkd if not unicodedata.combining(char))


def _resource_kind(court_type: str) -> str:
    return "bàn" if court_type == "billiards" else "sân"


def _resource_kind_title(court_type: str) -> str:
    return "Bàn" if court_type == "billiards" else "Sân"


def _optional_str(value) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
