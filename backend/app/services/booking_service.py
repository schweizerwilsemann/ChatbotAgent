import logging
from datetime import date, datetime, time, timedelta

from app.repositories.booking_repository import BookingRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.booking import (
    AvailabilityResponse,
    BookingCreate,
    BookingResponse,
    TimeSlotResponse,
)
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)

VALID_COURT_TYPES = {"billiards", "pickleball", "badminton"}


class BookingService:
    def __init__(
        self,
        repo: BookingRepository,
        notification_service: NotificationService | None = None,
        venue_repo: VenueRepository | None = None,
    ) -> None:
        self._repo = repo
        self._notification_service = notification_service
        self._venue_repo = venue_repo

    async def create_booking(
        self, data: BookingCreate, user_id: str, user=None
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

        venue_id = data.venue_id
        resource_id = data.resource_id
        resource_label = data.resource_label
        court_type = data.court_type
        court_number = data.court_number

        if self._venue_repo:
            resolved_venue_id = await self._venue_repo.resolve_user_venue_id(
                user,
                explicit_venue_id=venue_id,
            )
            venue_id = str(resolved_venue_id) if resolved_venue_id else venue_id

            resource = None
            if resource_id:
                resource = await self._venue_repo.get_resource_by_id(resource_id)
                if not resource:
                    raise ValueError("Selected table/court was not found")
            else:
                resource = await self._venue_repo.resolve_legacy_resource(
                    venue_id=venue_id,
                    court_type=court_type,
                    court_number=court_number,
                )

            if resource:
                venue_id = str(resource.venue_id)
                resource_id = str(resource.id)
                resource_label = data.resource_label or resource.name
                court_number = resource.number
                if resource.sport_type in VALID_COURT_TYPES:
                    court_type = resource.sport_type

        has_conflict = await self._repo.check_conflict(
            court_type=court_type,
            court_number=court_number,
            start_time=start_time,
            end_time=end_time,
            resource_id=resource_id,
        )
        if has_conflict:
            raise ValueError(
                f"{resource_label or f'Court {court_type} #{court_number}'} is already booked "
                f"for the requested time slot"
            )

        booking = await self._repo.create(
            user_id=user_id,
            venue_id=venue_id,
            resource_id=resource_id,
            resource_label=resource_label,
            court_type=court_type,
            court_number=court_number,
            start_time=start_time,
            end_time=end_time,
            notes=data.notes,
        )

        logger.info("Booking created: %s for user %s", booking.id, user_id)
        response = self._to_response(booking)
        if self._notification_service:
            await self._notification_service.notify_operations(
                event_type="booking.created",
                title="Đặt sân mới",
                message=(
                    f"Khách vừa đặt {response.resource_label or response.court_type} "
                    f"từ {response.start_time} đến {response.end_time}"
                ),
                source="booking",
                payload=response.model_dump(mode="json"),
            )
        return response

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

    async def get_active_user_booking(self, user_id: str) -> BookingResponse | None:
        """Get the user's current active booking (now between start and end)."""
        booking = await self._repo.get_active_booking(user_id)
        if not booking:
            return None
        return self._to_response(booking)

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
        resource_id: str | None = None,
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
            resource_id=resource_id,
        )
        return not has_conflict

    async def get_day_availability(
        self,
        court_type: str,
        selected_date: date,
        venue_id: str | None = None,
    ) -> AvailabilityResponse:
        """Return simple hourly availability for the selected court type/date."""
        if court_type not in VALID_COURT_TYPES:
            raise ValueError(f"Invalid court type: {court_type}")

        court_numbers = list(range(1, 5))
        resource_ids_by_number: dict[int, str] = {}
        if self._venue_repo:
            resource_rows = await self._venue_repo.list_resources(
                venue_id=venue_id,
                sport_type=court_type,
                status="active",
            )
            resources = [row["resource"] for row in resource_rows]
            if resources:
                court_numbers = [resource.number for resource in resources]
                resource_ids_by_number = {
                    resource.number: str(resource.id) for resource in resources
                }

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
                    resource_id=resource_ids_by_number.get(court_number),
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
            venue_id=str(booking.venue_id) if getattr(booking, "venue_id", None) else None,
            resource_id=str(booking.resource_id)
            if getattr(booking, "resource_id", None)
            else None,
            resource_label=getattr(booking, "resource_label", None),
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
