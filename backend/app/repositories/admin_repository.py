import uuid
from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from sqlalchemy import Date, String, and_, cast, false, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.booking import Booking

_local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
ACTIVE_BOOKING_STATUSES = ("confirmed", "checked_in")
from app.models.menu import MenuItem
from app.models.order import Order
from app.models.user import User
from app.models.venue import ResourceStatus, ServiceResource


class AdminRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # ------------------------------------------------------------------
    # Dashboard helpers
    # ------------------------------------------------------------------

    async def count_bookings_today(
        self,
        today: date,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> int:
        """Count bookings whose start_time falls on the given date."""
        day_start = datetime.combine(today, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(today, datetime.max.time(), tzinfo=_local_tz)
        stmt = select(func.count(Booking.id)).where(
            and_(
                Booking.start_time >= day_start,
                Booking.start_time <= day_end,
            )
        )
        stmt = _apply_booking_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return result.scalar() or 0

    async def count_orders_today(
        self,
        today: date,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> int:
        """Count orders whose created_at falls on the given date."""
        day_start = datetime.combine(today, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(today, datetime.max.time(), tzinfo=_local_tz)
        stmt = select(func.count(Order.id)).where(
            and_(
                Order.created_at >= day_start,
                Order.created_at <= day_end,
            )
        )
        stmt = _apply_order_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return result.scalar() or 0

    async def sum_order_revenue_today(
        self,
        today: date,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> Decimal:
        """Sum total_price for delivered/completed orders today."""
        day_start = datetime.combine(today, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(today, datetime.max.time(), tzinfo=_local_tz)
        stmt = select(func.coalesce(func.sum(Order.total_price), 0)).where(
            and_(
                Order.status.in_(["delivered"]),
                Order.created_at >= day_start,
                Order.created_at <= day_end,
            )
        )
        stmt = _apply_order_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return result.scalar() or Decimal("0")

    async def sum_booking_revenue_today(self, today: date) -> Decimal:
        """Sum total_price for bookings whose start_time falls on the given date."""
        day_start = datetime.combine(today, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(today, datetime.max.time(), tzinfo=_local_tz)
        stmt = select(func.coalesce(func.sum(Booking.total_price), 0)).where(
            and_(
                Booking.status.in_(["confirmed", "checked_in", "completed"]),
                Booking.start_time >= day_start,
                Booking.start_time <= day_end,
            )
        )
        result = await self._session.execute(stmt)
        return result.scalar() or Decimal("0")

    async def count_active_courts(
        self,
        now: datetime,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> int:
        """Count bookings that are currently active (confirmed and now between start/end)."""
        stmt = select(func.count(Booking.id)).where(
            and_(
                Booking.status.in_(ACTIVE_BOOKING_STATUSES),
                Booking.start_time <= now,
                Booking.end_time >= now,
            )
        )
        stmt = _apply_booking_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return result.scalar() or 0

    async def count_active_resources(
        self,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> int:
        stmt = select(func.count(ServiceResource.id)).where(
            ServiceResource.status == ResourceStatus.ACTIVE
        )
        stmt = _apply_resource_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return result.scalar() or 0

    # ------------------------------------------------------------------
    # Bookings with user info
    # ------------------------------------------------------------------

    async def get_all_bookings(
        self,
        *,
        date_filter: date | None = None,
        court_type: str | None = None,
        status: str | None = None,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
        limit: int | None = None,
        offset: int = 0,
    ) -> list[dict]:
        """Return bookings joined with user name, with optional filters."""
        stmt = (
            select(Booking, User.name.label("user_name"), User.phone.label("user_phone"))
            .outerjoin(User, Booking.user_id == cast(User.id, String))
            .order_by(Booking.updated_at.desc(), Booking.created_at.desc())
        )
        if date_filter:
            local_tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
            day_start = datetime.combine(date_filter, datetime.min.time(), tzinfo=local_tz)
            day_end = datetime.combine(date_filter, datetime.max.time(), tzinfo=local_tz)
            stmt = stmt.where(
                and_(
                    Booking.start_time >= day_start,
                    Booking.start_time <= day_end,
                )
            )
        if court_type:
            stmt = stmt.where(Booking.court_type == court_type)
        if status:
            stmt = stmt.where(Booking.status == status)
        stmt = _apply_booking_scope(stmt, venue_scope_ids, resource_ids)
        if limit is not None:
            stmt = stmt.offset(offset).limit(limit)

        result = await self._session.execute(stmt)
        rows = result.all()
        bookings = []
        for row in rows:
            booking = row[0]
            user_name = row[1]
            user_phone = row[2]
            bookings.append(
                {
                    "booking": booking,
                    "user_name": user_name,
                    "user_phone": user_phone,
                }
            )
        return bookings

    async def update_booking_status(
        self, booking_id: str, new_status: str
    ) -> Booking | None:
        """Update a booking's status and return the updated booking."""
        booking = await self.get_booking_by_id(booking_id)
        if not booking:
            return None
        booking.status = new_status
        await self._session.flush()
        return booking

    async def update_booking_payment_status(
        self, booking_id: str, payment_status: str
    ) -> Booking | None:
        booking = await self.get_booking_by_id(booking_id)
        if not booking:
            return None
        booking.payment_status = payment_status
        await self._session.flush()
        return booking

    async def get_booking_by_id(self, booking_id: str) -> Booking | None:
        stmt = select(Booking).where(Booking.id == uuid.UUID(booking_id))
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    # ------------------------------------------------------------------
    # Orders
    # ------------------------------------------------------------------

    async def get_all_orders(
        self,
        *,
        status: str | None = None,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
        limit: int | None = None,
        offset: int = 0,
    ) -> list[dict]:
        """Return all orders with items and user info, optionally filtered by status."""
        stmt = (
            select(Order, User.name.label("user_name"), User.phone.label("user_phone"))
            .options(selectinload(Order.items))
            .outerjoin(User, Order.user_id == cast(User.id, String))
            .order_by(Order.updated_at.desc(), Order.created_at.desc())
        )
        if status:
            stmt = stmt.where(Order.status == status)
        stmt = _apply_order_scope(stmt, venue_scope_ids, resource_ids)
        if limit is not None:
            stmt = stmt.offset(offset).limit(limit)
        result = await self._session.execute(stmt)
        rows = result.unique().all()
        orders = []
        for row in rows:
            order = row[0]
            user_name = row[1]
            user_phone = row[2]
            orders.append(
                {
                    "order": order,
                    "user_name": user_name,
                    "user_phone": user_phone,
                }
            )
        return orders

    async def get_orders_during_booking(self, booking: Booking) -> list[Order]:
        """Return non-cancelled orders created by this customer during a booking."""
        fallback_conditions = [
            Order.booking_id.is_(None),
            Order.user_id == booking.user_id,
            Order.created_at >= booking.start_time,
            Order.created_at <= booking.end_time,
        ]
        scope_conditions = []
        if booking.resource_id:
            scope_conditions.append(Order.resource_id == booking.resource_id)
        if booking.venue_id:
            scope_conditions.append(Order.venue_id == booking.venue_id)
        if scope_conditions:
            fallback_conditions.append(or_(*scope_conditions))

        stmt = (
            select(Order)
            .options(selectinload(Order.items))
            .where(
                Order.status != "cancelled",
                or_(
                    Order.booking_id == booking.id,
                    and_(*fallback_conditions),
                ),
            )
            .order_by(Order.created_at.asc())
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Menu items (admin – includes unavailable)
    # ------------------------------------------------------------------

    async def get_all_menu_items(
        self,
        *,
        category_key: str | None = None,
        query: str | None = None,
        venue_scope_ids: set[uuid.UUID] | None = None,
        limit: int | None = None,
        offset: int = 0,
    ) -> list[MenuItem]:
        """Return all menu items including unavailable ones."""
        stmt = select(MenuItem).where(
            MenuItem.is_deleted.is_(False)
        ).order_by(MenuItem.updated_at.desc(), MenuItem.created_at.desc())
        if category_key:
            stmt = stmt.where(MenuItem.category_key == category_key)
        if query:
            like_query = f"%{query}%"
            stmt = stmt.where(
                or_(
                    MenuItem.name.ilike(like_query),
                    MenuItem.category_name.ilike(like_query),
                    MenuItem.description.ilike(like_query),
                )
            )
        if venue_scope_ids is not None:
            if not venue_scope_ids:
                stmt = stmt.where(false())
            else:
                stmt = stmt.where(
                    or_(
                        MenuItem.venue_id.in_(list(venue_scope_ids)),
                        MenuItem.venue_id.is_(None),
                    )
                )
        if limit is not None:
            stmt = stmt.offset(offset).limit(limit)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_menu_item_by_id(self, item_id: str) -> MenuItem | None:
        stmt = select(MenuItem).where(
            MenuItem.id == uuid.UUID(item_id),
            MenuItem.is_deleted.is_(False),
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_menu_item(
        self,
        *,
        name: str,
        category_key: str,
        category_name: str,
        description: str,
        unit: str,
        price: Decimal,
        image_url: str | None,
        tags: str,
    ) -> MenuItem:
        item = MenuItem(
            id=uuid.uuid4(),
            name=name,
            category_key=category_key,
            category_name=category_name,
            description=description,
            unit=unit,
            price=price,
            image_url=image_url,
            tags=tags,
            sales_count=0,
            is_available=True,
        )
        self._session.add(item)
        await self._session.flush()
        return item

    async def update_menu_item(
        self,
        item_id: str,
        **kwargs,
    ) -> MenuItem | None:
        """Update a menu item's fields. Only non-None values are applied."""
        item = await self.get_menu_item_by_id(item_id)
        if not item:
            return None
        for key, value in kwargs.items():
            if value is not None and hasattr(item, key):
                setattr(item, key, value)
        await self._session.flush()
        await self._session.refresh(item)
        return item

    async def delete_menu_item(self, item_id: str) -> bool:
        item = await self.get_menu_item_by_id(item_id)
        if not item:
            return False
        await self._session.delete(item)
        await self._session.flush()
        return True

    async def set_menu_item_availability(
        self, item_id: str, is_available: bool
    ) -> MenuItem | None:
        item = await self.get_menu_item_by_id(item_id)
        if not item:
            return None
        item.is_available = is_available
        await self._session.flush()
        return item

    # ------------------------------------------------------------------
    # Analytics
    # ------------------------------------------------------------------

    async def revenue_by_day(
        self,
        start: date,
        end: date,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> list[dict]:
        """Sum of delivered order totals per day."""
        day_start = datetime.combine(start, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(end, datetime.max.time(), tzinfo=_local_tz)
        stmt = (
            select(
                cast(Order.created_at, Date).label("day"),
                func.coalesce(func.sum(Order.total_price), 0).label("revenue"),
            )
            .where(
                and_(
                    Order.status == "delivered",
                    Order.created_at >= day_start,
                    Order.created_at <= day_end,
                )
            )
            .group_by(cast(Order.created_at, Date))
            .order_by(cast(Order.created_at, Date))
        )
        stmt = _apply_order_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return [{"date": row[0], "revenue": row[1]} for row in result.all()]

    async def bookings_by_court(
        self,
        start: date,
        end: date,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> list[dict]:
        """Count bookings grouped by court_type and court_number."""
        day_start = datetime.combine(start, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(end, datetime.max.time(), tzinfo=_local_tz)
        stmt = (
            select(
                Booking.court_type,
                Booking.court_number,
                func.count(Booking.id).label("count"),
            )
            .where(
                and_(
                    Booking.start_time >= day_start,
                    Booking.start_time <= day_end,
                )
            )
            .group_by(Booking.court_type, Booking.court_number)
            .order_by(Booking.court_type, Booking.court_number)
        )
        stmt = _apply_booking_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return [
            {
                "court_type": row[0],
                "court_number": row[1],
                "count": row[2],
            }
            for row in result.all()
        ]

    async def orders_by_hour(
        self,
        start: date,
        end: date,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> list[dict]:
        """Count orders grouped by hour of day (peak hours)."""
        day_start = datetime.combine(start, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(end, datetime.max.time(), tzinfo=_local_tz)
        stmt = (
            select(
                func.extract("hour", Order.created_at).label("hour"),
                func.count(Order.id).label("count"),
            )
            .where(
                and_(
                    Order.created_at >= day_start,
                    Order.created_at <= day_end,
                )
            )
            .group_by(func.extract("hour", Order.created_at))
            .order_by(func.extract("hour", Order.created_at))
        )
        stmt = _apply_order_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return [{"hour": int(row[0]), "count": row[1]} for row in result.all()]

    async def order_count_by_day(
        self,
        start: date,
        end: date,
        *,
        venue_scope_ids: set[uuid.UUID] | None = None,
        resource_ids: set[uuid.UUID] | None = None,
    ) -> list[dict]:
        """Count orders per day."""
        day_start = datetime.combine(start, datetime.min.time(), tzinfo=_local_tz)
        day_end = datetime.combine(end, datetime.max.time(), tzinfo=_local_tz)
        stmt = (
            select(
                cast(Order.created_at, Date).label("day"),
                func.count(Order.id).label("count"),
            )
            .where(
                and_(
                    Order.created_at >= day_start,
                    Order.created_at <= day_end,
                )
            )
            .group_by(cast(Order.created_at, Date))
            .order_by(cast(Order.created_at, Date))
        )
        stmt = _apply_order_scope(stmt, venue_scope_ids, resource_ids)
        result = await self._session.execute(stmt)
        return [{"date": row[0], "count": row[1]} for row in result.all()]


def _apply_booking_scope(stmt, venue_scope_ids, resource_ids):
    if venue_scope_ids is None and resource_ids is None:
        return stmt
    scope_conditions = []
    if venue_scope_ids:
        scope_conditions.append(Booking.venue_id.in_(list(venue_scope_ids)))
    if resource_ids:
        scope_conditions.append(Booking.resource_id.in_(list(resource_ids)))
    if scope_conditions:
        return stmt.where(or_(*scope_conditions))
    return stmt.where(false())


def _apply_order_scope(stmt, venue_scope_ids, resource_ids):
    if venue_scope_ids is None and resource_ids is None:
        return stmt
    scope_conditions = []
    if venue_scope_ids:
        scope_conditions.append(Order.venue_id.in_(list(venue_scope_ids)))
    if resource_ids:
        scope_conditions.append(Order.resource_id.in_(list(resource_ids)))
    if scope_conditions:
        return stmt.where(or_(*scope_conditions))
    return stmt.where(false())


def _apply_resource_scope(stmt, venue_scope_ids, resource_ids):
    if venue_scope_ids is None and resource_ids is None:
        return stmt
    scope_conditions = []
    if venue_scope_ids:
        scope_conditions.append(ServiceResource.venue_id.in_(list(venue_scope_ids)))
    if resource_ids:
        scope_conditions.append(ServiceResource.id.in_(list(resource_ids)))
    if scope_conditions:
        return stmt.where(or_(*scope_conditions))
    return stmt.where(false())
