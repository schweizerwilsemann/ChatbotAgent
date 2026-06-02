import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import require_roles
from app.core.config import settings
from app.core.database import get_db
from app.models.user import User
from app.repositories.admin_repository import AdminRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.admin import (
    AdminBookingResponse,
    AnalyticsResponse,
    BookingBillResponse,
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

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin"])

VALID_BOOKING_TRANSITIONS = {
    "confirmed": {"cancelled", "completed"},
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
    local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
    start_local = booking.start_time.astimezone(local_tz) if booking.start_time.tzinfo else booking.start_time
    end_local = booking.end_time.astimezone(local_tz) if booking.end_time.tzinfo else booking.end_time
    return AdminBookingResponse(
        id=str(booking.id),
        user_id=booking.user_id,
        user_name=user_name,
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
        total_price=float(booking.total_price) if booking.total_price is not None else None,
        notes=booking.notes,
        created_at=getattr(booking, "created_at", None),
        updated_at=getattr(booking, "updated_at", None),
    )


def _order_response(order) -> OrderResponse:
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
        venue_id=str(order.venue_id) if getattr(order, "venue_id", None) else None,
        resource_id=str(order.resource_id)
        if getattr(order, "resource_id", None)
        else None,
        resource_label=getattr(order, "resource_label", None),
        table_number=order.table_number,
        status=order.status,
        total_price=order.total_price,
        notes=order.notes,
        items=items,
        created_at=getattr(order, "created_at", None),
    )


def _staff_order_response(order) -> StaffOrderResponse:
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
        venue_id=str(order.venue_id) if getattr(order, "venue_id", None) else None,
        resource_id=str(order.resource_id)
        if getattr(order, "resource_id", None)
        else None,
        resource_label=getattr(order, "resource_label", None),
        table_number=order.table_number,
        status=order.status,
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
    limit: int = Query(30, ge=1, le=100, description="Maximum rows to return"),
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

        entries = await repo.get_all_bookings(
            date_filter=booking.start_time.astimezone(ZoneInfo(settings.DEFAULT_TIMEZONE)).date() if booking.start_time.tzinfo else booking.start_time.date(),
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        booking_entry = next(
            (
                entry
                for entry in entries
                if str(entry["booking"].id) == str(booking.id)
            ),
            {"booking": booking, "user_name": None},
        )
        orders = await repo.get_orders_during_booking(booking)
        order_total = sum(
            (order.total_price for order in orders),
            start=Decimal("0"),
        )
        booking_total = (
            Decimal(str(booking.total_price))
            if booking.total_price is not None
            else None
        )
        return BookingBillResponse(
            booking=_booking_response(booking_entry),
            orders=[_order_response(order) for order in orders],
            order_total=order_total,
            booking_total=booking_total,
            grand_total=order_total + (booking_total or Decimal("0")),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error fetching booking bill")
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
        allowed = VALID_BOOKING_TRANSITIONS.get(current_status, set())
        if data.status not in allowed:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Cannot transition from '{current_status}' to '{data.status}'. "
                    f"Allowed transitions: {allowed or 'none (terminal state)'}"
                ),
            )

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

        # Build response with user_name
        user_repo_result = await repo.get_all_bookings(
            date_filter=updated.start_time.astimezone(ZoneInfo(settings.DEFAULT_TIMEZONE)).date() if updated.start_time.tzinfo else updated.start_time.date(),
            venue_scope_ids=venue_scope_ids,
            resource_ids=resource_ids,
        )
        user_name = None
        for entry in user_repo_result:
            if str(entry["booking"].id) == str(updated.id):
                user_name = entry["user_name"]
                break

        local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
        start_local = updated.start_time.astimezone(local_tz) if updated.start_time.tzinfo else updated.start_time
        end_local = updated.end_time.astimezone(local_tz) if updated.end_time.tzinfo else updated.end_time
        return AdminBookingResponse(
            id=str(updated.id),
            user_id=updated.user_id,
            user_name=user_name,
            venue_id=str(updated.venue_id)
            if getattr(updated, "venue_id", None)
            else None,
            resource_id=str(updated.resource_id)
            if getattr(updated, "resource_id", None)
            else None,
            resource_label=getattr(updated, "resource_label", None),
            court_type=updated.court_type,
            court_number=updated.court_number,
            date=start_local.date(),
            start_time=start_local.strftime("%H:%M"),
            end_time=end_local.strftime("%H:%M"),
            status=updated.status,
            total_price=float(updated.total_price) if updated.total_price is not None else None,
            notes=updated.notes,
            created_at=getattr(updated, "created_at", None),
            updated_at=getattr(updated, "updated_at", None),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error updating booking status")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/orders", response_model=list[OrderResponse])
async def get_all_orders(
    status: str | None = Query(None, description="Filter by status"),
    limit: int = Query(30, ge=1, le=100, description="Maximum rows to return"),
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
    limit: int = Query(30, ge=1, le=100, description="Maximum rows to return"),
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
    limit: int = Query(30, ge=1, le=100, description="Maximum rows to return"),
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
    user: User = Depends(require_roles("STAFF", "ADMIN")),
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
    user: User = Depends(require_roles("STAFF", "ADMIN")),
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
