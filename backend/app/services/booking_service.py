import logging
from datetime import date, datetime, time, timedelta

from app.repositories.booking_repository import BookingRepository
from app.schemas.booking import (
    AvailabilityResponse,
    BookingCreate,
    BookingResponse,
    TimeSlotResponse,
)

logger = logging.getLogger(__name__)

VALID_COURT_TYPES = {"billiards", "pickleball", "badminton"}


class BookingService:
    def __init__(self, repo: BookingRepository) -> None:
        self._repo = repo

    async def create_booking(
        self, data: BookingCreate, user_id: str
    ) -> BookingResponse:
        """Create a new booking after validating business rules."""
        if data.court_type not in VALID_COURT_TYPES:
            raise ValueError(
                f"Invalid court type: {data.court_type}. Must be one of {VALID_COURT_TYPES}"
            )

        start_time = data.to_start_datetime()
        end_time = data.to_end_datetime()

        if end_time <= start_time:
            raise ValueError("end_time must be after start_time")

        duration_hours = (end_time - start_time).total_seconds() / 3600
        if duration_hours > 12:
            raise ValueError("Booking duration cannot exceed 12 hours")

        if duration_hours < 0.5:
            raise ValueError("Booking duration must be at least 30 minutes")

        has_conflict = await self._repo.check_conflict(
            court_type=data.court_type,
            court_number=data.court_number,
            start_time=start_time,
            end_time=end_time,
        )
        if has_conflict:
            raise ValueError(
                f"Court {data.court_type} #{data.court_number} is already booked "
                f"for the requested time slot"
            )

        booking = await self._repo.create(
            user_id=user_id,
            court_type=data.court_type,
            court_number=data.court_number,
            start_time=start_time,
            end_time=end_time,
            notes=data.notes,
        )

        logger.info("Booking created: %s for user %s", booking.id, user_id)
        return self._to_response(booking)

    async def get_booking(self, booking_id: str) -> BookingResponse | None:
        """Get a booking by ID."""
        booking = await self._repo.get_by_id(booking_id)
        if not booking:
            return None
        return self._to_response(booking)

    async def get_user_bookings(self, user_id: str) -> list[BookingResponse]:
        """Get all bookings for a user."""
        bookings = await self._repo.get_by_user_id(user_id)
        return [self._to_response(b) for b in bookings]

    async def cancel_booking(self, booking_id: str) -> BookingResponse | None:
        """Cancel an existing booking."""
        booking = await self._repo.get_by_id(booking_id)
        if not booking:
            return None

        if booking.status == "cancelled":
            raise ValueError("Booking is already cancelled")

        if booking.status == "completed":
            raise ValueError("Cannot cancel a completed booking")

        cancelled = await self._repo.cancel(booking_id)
        if not cancelled:
            return None

        logger.info("Booking cancelled: %s", booking_id)
        return self._to_response(cancelled)

    async def check_availability(
        self,
        court_type: str,
        court_number: int,
        start_time: datetime,
        end_time: datetime,
    ) -> bool:
        """Check if a court is available for the given time slot."""
        if court_type not in VALID_COURT_TYPES:
            raise ValueError(f"Invalid court type: {court_type}")

        if end_time <= start_time:
            raise ValueError("end_time must be after start_time")

        has_conflict = await self._repo.check_conflict(
            court_type=court_type,
            court_number=court_number,
            start_time=start_time,
            end_time=end_time,
        )
        return not has_conflict

    async def get_day_availability(
        self,
        court_type: str,
        selected_date: date,
    ) -> AvailabilityResponse:
        """Return simple hourly availability for the selected court type/date."""
        if court_type not in VALID_COURT_TYPES:
            raise ValueError(f"Invalid court type: {court_type}")

        court_numbers = list(range(1, 5))
        slots: list[TimeSlotResponse] = []
        available_courts: set[int] = set()

        current = datetime.combine(selected_date, time(hour=8))
        closing = datetime.combine(selected_date, time(hour=22))
        while current < closing:
            next_time = current + timedelta(hours=1)
            slot_available = False
            for court_number in court_numbers:
                is_available = await self.check_availability(
                    court_type=court_type,
                    court_number=court_number,
                    start_time=current,
                    end_time=next_time,
                )
                if is_available:
                    slot_available = True
                    available_courts.add(court_number)

            slots.append(
                TimeSlotResponse(
                    start_time=current.strftime("%H:%M"),
                    end_time=next_time.strftime("%H:%M"),
                    is_available=slot_available,
                )
            )
            current = next_time

        return AvailabilityResponse(
            court_type=court_type,
            date=selected_date,
            slots=slots,
            available_courts=sorted(available_courts),
        )

    @staticmethod
    def _to_response(booking) -> BookingResponse:
        return BookingResponse(
            id=str(booking.id),
            user_id=booking.user_id,
            court_type=booking.court_type,
            court_number=booking.court_number,
            date=booking.start_time.date(),
            start_time=booking.start_time.strftime("%H:%M"),
            end_time=booking.end_time.strftime("%H:%M"),
            status=booking.status,
            total_price=None,
            notes=booking.notes,
            created_at=booking.created_at if hasattr(booking, "created_at") else None,
            updated_at=booking.updated_at if hasattr(booking, "updated_at") else None,
        )
