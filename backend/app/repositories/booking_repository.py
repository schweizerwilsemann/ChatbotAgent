import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import Booking


class BookingRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        user_id: str,
        court_type: str,
        court_number: int,
        start_time: datetime,
        end_time: datetime,
        notes: str = "",
        venue_id: str | uuid.UUID | None = None,
        resource_id: str | uuid.UUID | None = None,
        resource_label: str | None = None,
        total_price: float | None = None,
    ) -> Booking:
        booking = Booking(
            id=uuid.uuid4(),
            user_id=user_id,
            venue_id=_to_uuid_or_none(venue_id),
            resource_id=_to_uuid_or_none(resource_id),
            resource_label=resource_label,
            court_type=court_type,
            court_number=court_number,
            start_time=start_time,
            end_time=end_time,
            status="confirmed",
            notes=notes or None,
            total_price=total_price,
        )
        self._session.add(booking)
        await self._session.flush()
        return booking

    async def get_by_id(self, booking_id: str) -> Booking | None:
        stmt = select(Booking).where(Booking.id == uuid.UUID(booking_id))
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: str) -> list[Booking]:
        stmt = (
            select(Booking)
            .where(Booking.user_id == user_id)
            .order_by(Booking.start_time.desc())
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def cancel(self, booking_id: str) -> Booking | None:
        booking = await self.get_by_id(booking_id)
        if not booking:
            return None
        booking.status = "cancelled"
        await self._session.flush()
        return booking

    async def check_conflict(
        self,
        court_type: str,
        court_number: int,
        start_time: datetime,
        end_time: datetime,
        exclude_id: str | None = None,
        resource_id: str | uuid.UUID | None = None,
    ) -> bool:
        """Return True if a conflicting booking exists."""
        conditions = [
            Booking.status == "confirmed",
            Booking.start_time < end_time,
            Booking.end_time > start_time,
        ]
        if resource_id:
            conditions.append(Booking.resource_id == _to_uuid_or_none(resource_id))
        else:
            conditions.extend(
                [
                    Booking.court_type == court_type,
                    Booking.court_number == court_number,
                ]
            )
        if exclude_id:
            conditions.append(Booking.id != uuid.UUID(exclude_id))

        stmt = select(Booking).where(and_(*conditions)).limit(1)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def get_active_booking(self, user_id: str) -> Booking | None:
        """Return the user's current active booking (now between start and end)."""
        now = datetime.now(timezone.utc)
        stmt = (
            select(Booking)
            .where(
                Booking.user_id == user_id,
                Booking.status == "confirmed",
                Booking.start_time <= now,
                Booking.end_time > now,
            )
            .order_by(Booking.start_time.desc())
            .limit(1)
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_schedule(
        self,
        date: datetime,
        court_type: str = "",
        venue_id: str | uuid.UUID | None = None,
    ) -> list[Booking]:
        """Get all confirmed bookings for a given date."""
        day_start = date.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)

        conditions = [
            Booking.status == "confirmed",
            Booking.start_time >= day_start,
            Booking.start_time <= day_end,
        ]
        if court_type:
            conditions.append(Booking.court_type == court_type)
        if venue_id:
            conditions.append(Booking.venue_id == _to_uuid_or_none(venue_id))

        stmt = (
            select(Booking)
            .where(and_(*conditions))
            .order_by(Booking.court_type, Booking.court_number, Booking.start_time)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())


def _to_uuid_or_none(value: str | uuid.UUID | None) -> uuid.UUID | None:
    if value is None:
        return None
    if isinstance(value, uuid.UUID):
        return value
    return uuid.UUID(str(value))
