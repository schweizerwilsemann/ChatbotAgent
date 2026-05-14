import logging
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import require_roles
from app.core.database import get_db
from app.models.user import User
from app.repositories.admin_repository import AdminRepository
from app.repositories.notification_repository import NotificationRepository
from app.schemas.admin import (
    AdminBookingResponse,
    AnalyticsResponse,
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

TOTAL_COURTS = 8

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
    return AdminBookingResponse(
        id=str(booking.id),
        user_id=booking.user_id,
        user_name=user_name,
        court_type=booking.court_type,
        court_number=booking.court_number,
        date=booking.start_time.date(),
        start_time=booking.start_time.strftime("%H:%M"),
        end_time=booking.end_time.strftime("%H:%M"),
        status=booking.status,
        total_price=None,
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

        bookings_today = await repo.count_bookings_today(today)
        orders_today = await repo.count_orders_today(today)
        order_revenue = await repo.sum_order_revenue_today(today)
        booking_revenue = await repo.sum_booking_revenue_today(today)
        active_courts = await repo.count_active_courts(now)

        total_revenue = order_revenue + booking_revenue

        return DashboardResponse(
            total_revenue=total_revenue,
            bookings_today=bookings_today,
            orders_today=orders_today,
            active_courts=active_courts,
            total_courts=TOTAL_COURTS,
        )
    except Exception as exc:
        logger.exception("Error fetching dashboard")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/bookings", response_model=list[AdminBookingResponse])
async def get_all_bookings(
    date: date | None = Query(None, description="Filter by date"),
    court_type: str | None = Query(None, description="Filter by court type"),
    status: str | None = Query(None, description="Filter by status"),
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[AdminBookingResponse]:
    """Get all bookings with optional filters, including user name."""
    try:
        repo = _admin_repo(session)
        entries = await repo.get_all_bookings(
            date_filter=date,
            court_type=court_type,
            status=status,
        )
        return [_booking_response(entry) for entry in entries]
    except Exception as exc:
        logger.exception("Error fetching all bookings")
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
        notification_service = NotificationService(NotificationRepository(session))
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
            date_filter=updated.start_time.date(),
        )
        user_name = None
        for entry in user_repo_result:
            if str(entry["booking"].id) == str(updated.id):
                user_name = entry["user_name"]
                break

        return AdminBookingResponse(
            id=str(updated.id),
            user_id=updated.user_id,
            user_name=user_name,
            court_type=updated.court_type,
            court_number=updated.court_number,
            date=updated.start_time.date(),
            start_time=updated.start_time.strftime("%H:%M"),
            end_time=updated.end_time.strftime("%H:%M"),
            status=updated.status,
            total_price=None,
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
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[OrderResponse]:
    """Get all orders with optional status filter (ADMIN only - includes revenue)."""
    try:
        repo = _admin_repo(session)
        orders = await repo.get_all_orders(status=status)
        return [_order_response(order) for order in orders]
    except Exception as exc:
        logger.exception("Error fetching all orders")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/orders/staff", response_model=list[StaffOrderResponse])
async def get_staff_orders(
    status: str | None = Query(None, description="Filter by status"),
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[StaffOrderResponse]:
    """Get orders for staff view (no revenue details)."""
    try:
        repo = _admin_repo(session)
        orders = await repo.get_all_orders(status=status)
        return [_staff_order_response(order) for order in orders]
    except Exception as exc:
        logger.exception("Error fetching staff orders")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/menu", response_model=list[MenuItemResponse])
async def get_all_menu_items(
    category_key: str | None = Query(None, description="Filter by category key"),
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[MenuItemResponse]:
    """Get ALL menu items including unavailable ones."""
    try:
        repo = _admin_repo(session)
        items = await repo.get_all_menu_items(category_key=category_key)
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

        revenue_data = await repo.revenue_by_day(start, end)
        bookings_data = await repo.bookings_by_court(start, end)
        hours_data = await repo.orders_by_hour(start, end)
        orders_data = await repo.order_count_by_day(start, end)

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
