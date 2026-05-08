import logging
from datetime import datetime

from app.repositories.booking_repository import BookingRepository
from app.schemas.booking import (
    BookingCancelResponse,
    BookingCreate,
    BookingResponse,
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

        if data.end_time <= data.start_time:
            raise ValueError("end_time must be after start_time")

        duration_hours = (data.end_time - data.start_time).total_seconds() / 3600
        if duration_hours > 12:
            raise ValueError("Booking duration cannot exceed 12 hours")

        if duration_hours < 0.5:
            raise ValueError("Booking duration must be at least 30 minutes")

        has_conflict = await self._repo.check_conflict(
            court_type=data.court_type,
            court_number=data.court_number,
            start_time=data.start_time,
            end_time=data.end_time,
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
            start_time=data.start_time,
            end_time=data.end_time,
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

    async def cancel_booking(self, booking_id: str) -> BookingCancelResponse | None:
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
        return BookingCancelResponse(
            id=str(cancelled.id),
            status=cancelled.status,
            message="Đặt sân đã được hủy thành công.",
        )

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

    @staticmethod
    def _to_response(booking) -> BookingResponse:
        return BookingResponse(
            id=str(booking.id),
            user_id=booking.user_id,
            court_type=booking.court_type,
            court_number=booking.court_number,
            start_time=booking.start_time,
            end_time=booking.end_time,
            status=booking.status,
            notes=booking.notes,
            created_at=booking.created_at if hasattr(booking, "created_at") else None,
        )
