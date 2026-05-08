import uuid
from datetime import datetime

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
    ) -> Booking:
        booking = Booking(
            id=uuid.uuid4(),
            user_id=user_id,
            court_type=court_type,
            court_number=court_number,
            start_time=start_time,
            end_time=end_time,
            status="confirmed",
            notes=notes or None,
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
    ) -> bool:
        """Return True if a conflicting booking exists."""
        conditions = [
            Booking.court_type == court_type,
            Booking.court_number == court_number,
            Booking.status == "confirmed",
            Booking.start_time < end_time,
            Booking.end_time > start_time,
        ]
        if exclude_id:
            conditions.append(Booking.id != uuid.UUID(exclude_id))

        stmt = select(Booking).where(and_(*conditions)).limit(1)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def get_schedule(
        self,
        date: datetime,
        court_type: str = "",
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

        stmt = (
            select(Booking)
            .where(and_(*conditions))
            .order_by(Booking.court_type, Booking.court_number, Booking.start_time)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())
