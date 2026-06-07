import logging
import secrets
import uuid
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import require_roles
from app.core.config import settings
from app.core.database import get_db
from app.models.user import User
from app.repositories.booking_repository import BookingRepository
from app.repositories.admin_repository import AdminRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.admin import (
    AdminBookingResponse,
    AnalyticsResponse,
    BookingBillResponse,
    BookingCheckInTokenResponse,
    BookingRescheduleUpdate,
    BookingStatusUpdate,
    CourtBookingCount,
    DashboardResponse,
    DayOrderCount,
    DayRevenue,
    HourOrderCount,
    MenuItemAvailabilityUpdate,
    MenuItemCreate,
    MenuItemResponse,
    MenuItemUpdate,
)
from app.schemas.order import OrderItemResponse, OrderResponse, StaffOrderItemResponse, StaffOrderResponse
from app.services.notification_service import NotificationService
from app.services.realtime import realtime_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin"])

VALID_BOOKING_TRANSITIONS = {
    "confirmed": {"checked_in", "cancelled", "completed"},
    "checked_in": {"completed"},
    "cancelled": set(),
    "completed": set(),
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _admin_repo(session: AsyncSession) -> AdminRepository:
    return AdminRepository(session)


def _menu_item_response(item) -> MenuItemResponse:
    return MenuItemResponse(
        id=str(item.id),
        name=item.name,
        description=(item.description or item.unit or "").strip(),
        price=item.price,
        image_url=item.image_url,
        category=item.category_name,
        category_key=item.category_key,
        unit=item.unit,
        tags=item.tags,
        sales_count=item.sales_count,
        is_available=item.is_available,
        created_at=getattr(item, "created_at", None),
        updated_at=getattr(item, "updated_at", None),
    )


def _booking_response(entry: dict) -> AdminBookingResponse:
    booking = entry["booking"]
    user_name = entry["user_name"]
    user_phone = entry.get("user_phone")
    local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
    # Always convert to local time - handle both aware and naive datetimes
    start = booking.start_time
    end = booking.end_time
    if start.tzinfo is None:
        start = start.replace(tzinfo=timezone.utc)
    if end.tzinfo is None:
        end = end.replace(tzinfo=timezone.utc)
    start_local = start.astimezone(local_tz)
    end_local = end.astimezone(local_tz)
    return AdminBookingResponse(
        id=str(booking.id),
        user_id=booking.user_id,
        user_name=user_name,
        user_phone=user_phone,
        venue_id=str(booking.venue_id) if getattr(booking, "venue_id", None) else None,
        resource_id=str(booking.resource_id)
        if getattr(booking, "resource_id", None)
        else None,
        resource_label=getattr(booking, "resource_label", None),
        court_type=booking.court_type,
        court_number=booking.court_number,
        date=start_local.date(),
        start_time=start_local.strftime("%H:%M"),
        end_time=end_local.strftime("%H:%M"),
        status=booking.status,
        payment_status=getattr(booking, "payment_status", None) or "unpaid",
        total_price=float(booking.total_price) if booking.total_price is not None else None,
        notes=booking.notes,
        checked_in_at=getattr(booking, "checked_in_at", None),
        checked_in_by=getattr(booking, "checked_in_by", None),
        created_at=getattr(booking, "created_at", None),
        updated_at=getattr(booking, "updated_at", None),
    )


def _order_response(entry: dict) -> OrderResponse:
    order = entry["order"]
    user_name = entry.get("user_name")
    user_phone = entry.get("user_phone")
    items = [
        OrderItemResponse(
            id=str(item.id),
            item_name=item.item_name,
            quantity=item.quantity,
            unit_price=item.unit_price,
            total_price=item.unit_price * item.quantity,
        )
        for item in order.items
    ]
    return OrderResponse(
        id=str(order.id),
        user_id=order.user_id,
        user_name=user_name,
        user_phone=user_phone,
        venue_id=str(order.venue_id) if getattr(order, "venue_id", None) else None,
        resource_id=str(order.resource_id)
        if getattr(order, "resource_id", None)
        else None,
        resource_label=getattr(order, "resource_label", None),
        table_number=order.table_number,
        status=order.status,
        payment_status=getattr(order, "payment_status", None) or "unpaid",
        total_price=order.total_price,
        notes=order.notes,
        items=items,
        created_at=getattr(order, "created_at", None),
    )


def _staff_order_response(entry: dict) -> StaffOrderResponse:
    order = entry["order"]
    user_name = entry.get("user_name")
    user_phone = entry.get("user_phone")
    items = [
        StaffOrderItemResponse(
            id=str(item.id),
            item_name=item.item_name,
            quantity=item.quantity,
        )
        for item in order.items
    ]
    return StaffOrderResponse(
        id=str(order.id),
        user_id=order.user_id,
        user_name=user_name,
        user_phone=user_phone,
        venue_id=str(order.venue_id) if getattr(order, "venue_id", None) else None,
        resource_id=str(order.resource_id)
        if getattr(order, "resource_id", None)
        else None,
        resource_label=getattr(order, "resource_label", None),
        table_number=order.table_number,
        status=order.status,
        payment_status=getattr(order, "payment_status", None) or "unpaid",
        notes=order.notes,
        items=items,
        created_at=getattr(order, "created_at", None),
    )


def _period_to_dates(period: str) -> tuple[date, date]:
    """Convert a period string to (start_date, end_date)."""
    today = date.today()
    if period == "today":
        return today, today
    elif period == "week":
        return today - timedelta(days=7), today
    elif period == "month":
        return today - timedelta(days=30), today
    elif period == "year":
        return today - timedelta(days=365), today
    return today - timedelta(days=30), today


async def _operation_scope(
    user: User,
    session: AsyncSession,
) -> tuple[set[uuid.UUID] | None, set[uuid.UUID] | None]:
    """Return venue/resource IDs this operations user is allowed to see.

    None means unrestricted, used only for legacy/global admins.
    """
    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    default_venue_id = getattr(user, "default_venue_id", None)

    if role_value == "ADMIN":
        if default_venue_id:
            return {default_venue_id}, None
        return None, None

    if role_value == "STAFF":
        venue_repo = VenueRepository(session)
        access = await venue_repo.get_staff_access(str(user.id))
        if access.has_assignments:
            resource_ids = await venue_repo.expand_accessible_resource_ids(access)
            return access.venue_scope_ids, resource_ids
        if default_venue_id:
            return {default_venue_id}, None
        return set(), set()

    return None, None


async def _menu_venue_scope(
    user: User,
    session: AsyncSession,
) -> set[uuid.UUID] | None:
    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    default_venue_id = getattr(user, "default_venue_id", None)

    if role_value == "ADMIN":
        return {default_venue_id} if default_venue_id else None

    if role_value == "STAFF":
        venue_repo = VenueRepository(session)
        access = await venue_repo.get_staff_access(str(user.id))
        if access.has_assignments:
            return access.venue_ids
        if default_venue_id:
            return {default_venue_id}
        return set()

    return set()


def _is_in_scope(
    *,
    venue_id,
    resource_id,
    venue_scope_ids: set[uuid.UUID] | None,
    resource_ids: set[uuid.UUID] | None,
) -> bool:
    if venue_scope_ids is None and resource_ids is None:
        return True
    if venue_id and venue_scope_ids and venue_id in venue_scope_ids:
        return True
    if resource_id and resource_ids and resource_id in resource_ids:
        return True
    return False


def _is_paid_status(payment_status: str | None) -> bool:
    return (payment_status or "").startswith("paid")


def _booking_local_date(booking) -> date:
    local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
    if booking.start_time.tzinfo:
        return booking.start_time.astimezone(local_tz).date()
    return booking.start_time.date()


async def _booking_entry(
    repo: AdminRepository,
    booking,
    *,
    venue_scope_ids: set[uuid.UUID] | None,
    resource_ids: set[uuid.UUID] | None,
) -> dict:
    entries = await repo.get_all_bookings(
        date_filter=_booking_local_date(booking),
        venue_scope_ids=venue_scope_ids,
        resource_ids=resource_ids,
    )
    return next(
        (
            entry
            for entry in entries
            if str(entry["booking"].id) == str(booking.id)
        ),
        {"booking": booking, "user_name": None, "user_phone": None},
    )


def _booking_bill_response(booking_entry: dict, orders) -> BookingBillResponse:
    booking = booking_entry["booking"]
    order_total = sum(
        (order.total_price for order in orders),
        start=Decimal("0"),
    )
    booking_total = (
        Decimal(str(booking.total_price)) if booking.total_price is not None else None
    )
    grand_total = order_total + (booking_total or Decimal("0"))
    paid_total = sum(
        (
            order.total_price
            for order in orders
            if _is_paid_status(getattr(order, "payment_status", None))
        ),
        start=Decimal("0"),
    )
    if booking_total is not None and _is_paid_status(
        getattr(booking, "payment_status", None)
    ):
        paid_total += booking_total
    unpaid_total = max(grand_total - paid_total, Decimal("0"))

    bill_user_name = booking_entry.get("user_name")
    bill_user_phone = booking_entry.get("user_phone")
    order_entries = [
        {"order": order, "user_name": bill_user_name, "user_phone": bill_user_phone}
        for order in orders
    ]
    return BookingBillResponse(
        booking=_booking_response(booking_entry),
        orders=[_order_response(entry) for entry in order_entries],
        order_total=order_total,
        booking_total=booking_total,
        grand_total=grand_total,
        paid_total=paid_total,
        unpaid_total=unpaid_total,
    )


def _checkin_qr_payload(booking_id: str, token: str) -> str:
    return f"sportsvenue://booking-checkin?booking_id={booking_id}&token={token}"


def _combine_booking_datetime(booking, value_date: date | None, value: datetime | str):
    local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
    if isinstance(value, datetime):
        return value.replace(tzinfo=local_tz) if value.tzinfo is None else value
    base_date = value_date or _booking_local_date(booking)
    parsed_time = time.fromisoformat(value)
    return datetime.combine(base_date, parsed_time, tzinfo=local_tz)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("/dashboard", response_model=DashboardResponse)
async def dashboard(
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> DashboardResponse:
    """Return today's summary statistics."""
    try:
        repo = _admin_repo(session)
        today = date.today()
        now = datetime.now(timezone.utc)
        venue_scope_ids, resource_ids = await _operation_scope(user, session)

        bookings_today = await repo.count_bookings_today(
            today,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        orders_today = await repo.count_orders_today(
            today,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        order_revenue = await repo.sum_order_revenue_today(
            today,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        booking_revenue = await repo.sum_booking_revenue_today(today)
        active_courts = await repo.count_active_courts(
            now,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        total_courts = await repo.count_active_resources(
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )

        total_revenue = order_revenue + booking_revenue

        return DashboardResponse(
            total_revenue=total_revenue,
            bookings_today=bookings_today,
            orders_today=orders_today,
            active_courts=active_courts,
            total_courts=total_courts,
        )
    except Exception as exc:
        logger.exception("Error fetching dashboard")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/bookings", response_model=list[AdminBookingResponse])
async def get_all_bookings(
    date: date | None = Query(None, description="Filter by date"),
    court_type: str | None = Query(None, description="Filter by court type"),
    status: str | None = Query(None, description="Filter by status"),
    limit: int = Query(10, ge=1, le=100, description="Maximum rows to return"),
    offset: int = Query(0, ge=0, description="Rows to skip"),
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[AdminBookingResponse]:
    """Get all bookings with optional filters, including user name."""
    try:
        repo = _admin_repo(session)
        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        entries = await repo.get_all_bookings(
            date_filter=date,
            court_type=court_type,
            status=status,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
            limit=limit,
            offset=offset,
        )
        return [_booking_response(entry) for entry in entries]
    except Exception as exc:
        logger.exception("Error fetching all bookings")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/bookings/{booking_id}/bill", response_model=BookingBillResponse)
async def get_booking_bill(
    booking_id: str,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> BookingBillResponse:
    """Aggregate orders created by the same customer during a booking."""
    try:
        repo = _admin_repo(session)
        booking = await repo.get_booking_by_id(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        if not _is_in_scope(
            venue_id=booking.venue_id,
            resource_id=booking.resource_id,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        ):
            raise HTTPException(
                status_code=403,
                detail="Booking is outside your assigned venue",
            )

        booking_entry = await _booking_entry(
            repo,
            booking,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        orders = await repo.get_orders_during_booking(booking)
        return _booking_bill_response(booking_entry, orders)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error fetching booking bill")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.post(
    "/bookings/{booking_id}/checkin-token",
    response_model=BookingCheckInTokenResponse,
)
async def create_booking_checkin_token(
    booking_id: str,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> BookingCheckInTokenResponse:
    """Create a one-time token that can be rendered as a QR for customer check-in."""
    try:
        repo = _admin_repo(session)
        booking_repo = BookingRepository(session)
        booking = await repo.get_booking_by_id(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        if not _is_in_scope(
            venue_id=booking.venue_id,
            resource_id=booking.resource_id,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        ):
            raise HTTPException(
                status_code=403,
                detail="Booking is outside your assigned venue",
            )
        if booking.status in {"cancelled", "completed"}:
            raise HTTPException(
                status_code=400,
                detail="Cannot create check-in QR for a terminal booking",
            )

        token = secrets.token_urlsafe(32)
        updated = await booking_repo.set_checkin_token(booking_id, token)
        if not updated:
            raise HTTPException(status_code=404, detail="Booking not found")
        booking_entry = await _booking_entry(
            repo,
            updated,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        return BookingCheckInTokenResponse(
            booking=_booking_response(booking_entry),
            token=token,
            qr_payload=_checkin_qr_payload(booking_id, token),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error creating booking check-in token")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.post("/bookings/{booking_id}/check-in", response_model=AdminBookingResponse)
async def staff_check_in_booking(
    booking_id: str,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> AdminBookingResponse:
    """Staff/admin fallback to mark a customer as checked in without the QR scan."""
    try:
        repo = _admin_repo(session)
        booking_repo = BookingRepository(session)
        booking = await repo.get_booking_by_id(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        if not _is_in_scope(
            venue_id=booking.venue_id,
            resource_id=booking.resource_id,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        ):
            raise HTTPException(
                status_code=403,
                detail="Booking is outside your assigned venue",
            )
        if booking.status == "checked_in":
            booking_entry = await _booking_entry(
                repo,
                booking,
                venue_scope_ids=venue_scope_ids,
                resource_ids=resource_ids,
            )
            return _booking_response(booking_entry)
        if booking.status != "confirmed":
            raise HTTPException(
                status_code=400,
                detail=f"Cannot check in booking with status '{booking.status}'",
            )

        updated = await booking_repo.confirm_checkin(
            booking_id,
            checked_in_by=str(user.id),
        )
        if not updated:
            raise HTTPException(status_code=404, detail="Booking not found")

        notification_service = NotificationService(
            NotificationRepository(session),
            VenueRepository(session),
        )
        await notification_service.notify_operations(
            event_type="booking.checked_in",
            title="Khách đã nhận sân",
            message=(
                f"{updated.resource_label or f'Sân {updated.court_number}'} "
                "đã được xác nhận nhận sân"
            ),
            source="admin",
            payload={
                "booking_id": str(updated.id),
                "status": "checked_in",
                "checked_in_by": str(user.id),
            },
        )
        await realtime_manager.broadcast_ui_event(
            ["STAFF", "ADMIN"],
            "court_status_changed",
            {
                "booking_id": str(updated.id),
                "resource_id": str(updated.resource_id) if updated.resource_id else "",
                "resource_label": updated.resource_label or "",
                "status": "checked_in",
                "start_time": updated.start_time.isoformat() if updated.start_time else None,
                "end_time": updated.end_time.isoformat() if updated.end_time else None,
            },
        )

        booking_entry = await _booking_entry(
            repo,
            updated,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        return _booking_response(booking_entry)
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error checking in booking")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.patch("/bookings/{booking_id}/reschedule", response_model=AdminBookingResponse)
async def reschedule_booking(
    booking_id: str,
    data: BookingRescheduleUpdate,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> AdminBookingResponse:
    """Move a booking to another start/end time after checking court availability."""
    try:
        repo = _admin_repo(session)
        booking_repo = BookingRepository(session)
        venue_repo = VenueRepository(session)
        booking = await repo.get_booking_by_id(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        if not _is_in_scope(
            venue_id=booking.venue_id,
            resource_id=booking.resource_id,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        ):
            raise HTTPException(
                status_code=403,
                detail="Booking is outside your assigned venue",
            )
        if booking.status in {"cancelled", "completed"}:
            raise HTTPException(
                status_code=400,
                detail="Cannot reschedule a terminal booking",
            )

        start_time = _combine_booking_datetime(booking, data.date, data.start_time)
        end_time = _combine_booking_datetime(booking, data.date, data.end_time)
        if end_time <= start_time:
            raise HTTPException(status_code=400, detail="end_time must be after start_time")

        has_conflict = await booking_repo.check_conflict(
            court_type=booking.court_type,
            court_number=booking.court_number,
            start_time=start_time,
            end_time=end_time,
            exclude_id=booking_id,
            resource_id=str(booking.resource_id) if booking.resource_id else None,
        )
        if has_conflict:
            raise HTTPException(
                status_code=409,
                detail="Selected time slot is already occupied",
            )

        total_price = (
            float(booking.total_price) if booking.total_price is not None else None
        )
        if booking.resource_id:
            resource = await venue_repo.get_resource_by_id(str(booking.resource_id))
            if resource and resource.hourly_rate is not None:
                duration_hours = (end_time - start_time).total_seconds() / 3600
                total_price = float(resource.hourly_rate) * duration_hours

        updated = await booking_repo.reschedule(
            booking_id,
            start_time=start_time,
            end_time=end_time,
            total_price=total_price,
        )
        if not updated:
            raise HTTPException(status_code=404, detail="Booking not found")

        notification_service = NotificationService(
            NotificationRepository(session),
            VenueRepository(session),
        )
        local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
        start_label = start_time.astimezone(local_tz).strftime("%H:%M")
        end_label = end_time.astimezone(local_tz).strftime("%H:%M")
        await notification_service.notify_operations(
            event_type="booking.rescheduled",
            title="Đổi giờ đặt sân",
            message=(
                f"{updated.resource_label or f'Sân {updated.court_number}'} "
                f"đổi sang {start_label} - {end_label}"
            ),
            source="admin",
            payload={
                "booking_id": str(updated.id),
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "changed_by": str(user.id),
            },
        )

        booking_entry = await _booking_entry(
            repo,
            updated,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        return _booking_response(booking_entry)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error rescheduling booking")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.patch("/bookings/{booking_id}/status", response_model=AdminBookingResponse)
async def update_booking_status(
    booking_id: str,
    data: BookingStatusUpdate,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> AdminBookingResponse:
    """Update a booking's status with transition validation."""
    try:
        repo = _admin_repo(session)

        booking = await repo.get_booking_by_id(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")
        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        if not _is_in_scope(
            venue_id=booking.venue_id,
            resource_id=booking.resource_id,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        ):
            raise HTTPException(
                status_code=403,
                detail="Booking is outside your assigned venue",
            )

        current_status = booking.status
        ps = getattr(booking, "payment_status", None) or ""
        if data.status == "cancelled" and ps.startswith("paid"):
            raise HTTPException(
                status_code=400,
                detail="Paid bookings cannot be cancelled without a refund flow",
            )

        allowed = VALID_BOOKING_TRANSITIONS.get(current_status, set())
        if data.status not in allowed:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Cannot transition from '{current_status}' to '{data.status}'. "
                    f"Allowed transitions: {allowed or 'none (terminal state)'}"
                ),
            )

        if data.status == "checked_in":
            updated = await BookingRepository(session).confirm_checkin(
                booking_id,
                checked_in_by=str(user.id),
            )
        else:
            updated = await repo.update_booking_status(booking_id, data.status)
        if not updated:
            raise HTTPException(status_code=404, detail="Booking not found")

        logger.info(
            "Booking %s status updated from %s to %s by %s",
            booking_id,
            current_status,
            data.status,
            user.id,
        )

        # Send notification on status change
        notification_service = NotificationService(
            NotificationRepository(session),
            VenueRepository(session),
        )
        status_label = {
            "confirmed": "xác nhận",
            "checked_in": "nhận sân",
            "cancelled": "hủy",
            "completed": "hoàn thành",
        }.get(data.status, data.status)
        await notification_service.notify_operations(
            event_type="booking.status_changed",
            title="Cập nhật trạng thái đặt sân",
            message=(
                f"Đặt sân {updated.court_type} #{updated.court_number} "
                f"đã được {status_label}"
            ),
            source="admin",
            payload={
                "booking_id": str(updated.id),
                "status": data.status,
                "changed_by": str(user.id),
            },
        )
        await realtime_manager.broadcast_ui_event(
            ["STAFF", "ADMIN"],
            "court_status_changed",
            {
                "booking_id": str(updated.id),
                "resource_id": str(updated.resource_id) if updated.resource_id else "",
                "resource_label": updated.resource_label or "",
                "status": data.status,
                "start_time": updated.start_time.isoformat() if updated.start_time else None,
                "end_time": updated.end_time.isoformat() if updated.end_time else None,
            },
        )

        booking_entry = await _booking_entry(
            repo,
            updated,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        return _booking_response(booking_entry)
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error updating booking status")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/orders", response_model=list[OrderResponse])
async def get_all_orders(
    status: str | None = Query(None, description="Filter by status"),
    limit: int = Query(10, ge=1, le=100, description="Maximum rows to return"),
    offset: int = Query(0, ge=0, description="Rows to skip"),
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[OrderResponse]:
    """Get all orders with optional status filter (ADMIN only - includes revenue)."""
    try:
        repo = _admin_repo(session)
        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        orders = await repo.get_all_orders(
            status=status,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
            limit=limit,
            offset=offset,
        )
        return [_order_response(order) for order in orders]
    except Exception as exc:
        logger.exception("Error fetching all orders")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/orders/staff", response_model=list[StaffOrderResponse])
async def get_staff_orders(
    status: str | None = Query(None, description="Filter by status"),
    limit: int = Query(10, ge=1, le=100, description="Maximum rows to return"),
    offset: int = Query(0, ge=0, description="Rows to skip"),
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[StaffOrderResponse]:
    """Get orders for staff view (no revenue details)."""
    try:
        repo = _admin_repo(session)
        venue_scope_ids, resource_ids = await _operation_scope(user, session)
        orders = await repo.get_all_orders(
            status=status,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
            limit=limit,
            offset=offset,
        )
        return [_staff_order_response(order) for order in orders]
    except Exception as exc:
        logger.exception("Error fetching staff orders")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/menu", response_model=list[MenuItemResponse])
async def get_all_menu_items(
    category_key: str | None = Query(None, description="Filter by category key"),
    q: str | None = Query(None, max_length=100, description="Search menu items"),
    limit: int = Query(10, ge=1, le=100, description="Maximum rows to return"),
    offset: int = Query(0, ge=0, description="Rows to skip"),
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[MenuItemResponse]:
    """Get ALL menu items including unavailable ones."""
    try:
        repo = _admin_repo(session)
        query = q.strip() if q else None
        venue_scope_ids = await _menu_venue_scope(user, session)
        items = await repo.get_all_menu_items(
            category_key=category_key,
            query=query,
            venue_scope_ids=venue_scope_ids,
            limit=limit,
            offset=offset,
        )
        return [_menu_item_response(item) for item in items]
    except Exception as exc:
        logger.exception("Error fetching all menu items")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.post("/menu", response_model=MenuItemResponse, status_code=201)
async def create_menu_item(
    data: MenuItemCreate,
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> MenuItemResponse:
    """Create a new menu item."""
    try:
        repo = _admin_repo(session)
        item = await repo.create_menu_item(
            name=data.name,
            category_key=data.category_key,
            category_name=data.category_name,
            description=data.description,
            unit=data.unit,
            price=data.price,
            image_url=data.image_url,
            tags=data.tags,
        )
        logger.info("Menu item created: %s by %s", item.id, user.id)
        return _menu_item_response(item)
    except Exception as exc:
        logger.exception("Error creating menu item")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.put("/menu/{item_id}", response_model=MenuItemResponse)
async def update_menu_item(
    item_id: str,
    data: MenuItemUpdate,
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> MenuItemResponse:
    """Update a menu item. Only provided fields are updated."""
    try:
        repo = _admin_repo(session)
        update_fields = data.model_dump(exclude_unset=True)
        if not update_fields:
            raise HTTPException(status_code=400, detail="No fields to update")

        item = await repo.update_menu_item(item_id, **update_fields)
        if not item:
            raise HTTPException(status_code=404, detail="Menu item not found")

        logger.info("Menu item %s updated by %s", item_id, user.id)
        return _menu_item_response(item)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error updating menu item")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.delete("/menu/{item_id}", status_code=204)
async def delete_menu_item(
    item_id: str,
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> None:
    """Delete a menu item."""
    try:
        repo = _admin_repo(session)
        deleted = await repo.delete_menu_item(item_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Menu item not found")
        logger.info("Menu item %s deleted by %s", item_id, user.id)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error deleting menu item")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.patch("/menu/{item_id}/availability", response_model=MenuItemResponse)
async def toggle_menu_item_availability(
    item_id: str,
    data: MenuItemAvailabilityUpdate,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> MenuItemResponse:
    """Toggle a menu item's availability."""
    try:
        repo = _admin_repo(session)
        item = await repo.set_menu_item_availability(item_id, data.is_available)
        if not item:
            raise HTTPException(status_code=404, detail="Menu item not found")

        logger.info(
            "Menu item %s availability set to %s by %s",
            item_id,
            data.is_available,
            user.id,
        )
        return _menu_item_response(item)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error toggling menu item availability")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/analytics", response_model=AnalyticsResponse)
async def analytics(
    period: str = Query(
        "month",
        description="Time period: today, week, month, year",
    ),
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> AnalyticsResponse:
    """Return analytics data for the requested period."""
    try:
        repo = _admin_repo(session)
        start, end = _period_to_dates(period)
        venue_scope_ids, resource_ids = await _operation_scope(user, session)

        revenue_data = await repo.revenue_by_day(
            start,
            end,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        bookings_data = await repo.bookings_by_court(
            start,
            end,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        hours_data = await repo.orders_by_hour(
            start,
            end,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        orders_data = await repo.order_count_by_day(
            start,
            end,
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )

        return AnalyticsResponse(
            revenue_by_day=[
                DayRevenue(date=row["date"], revenue=row["revenue"])
                for row in revenue_data
            ],
            bookings_by_court=[
                CourtBookingCount(
                    court_type=row["court_type"],
                    court_number=row["court_number"],
                    count=row["count"],
                )
                for row in bookings_data
            ],
            orders_by_hour=[
                HourOrderCount(hour=row["hour"], count=row["count"])
                for row in hours_data
            ],
            order_count_by_day=[
                DayOrderCount(date=row["date"], count=row["count"])
                for row in orders_data
            ],
        )
    except Exception as exc:
        logger.exception("Error fetching analytics")
        raise HTTPException(status_code=500, detail="Internal server error") from exc
