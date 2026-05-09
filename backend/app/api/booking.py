import logging
from datetime import date as DateType
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.repositories.booking_repository import BookingRepository
from app.schemas.booking import (
    AvailabilityResponse,
    BookingCreate,
    BookingResponse,
)
from app.services.booking_service import BookingService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/booking", tags=["booking"])


async def _get_booking_service(
    session: AsyncSession = Depends(get_db),
) -> BookingService:
    repo = BookingRepository(session)
    return BookingService(repo)


@router.post("/", response_model=BookingResponse, status_code=201)
async def create_booking(
    data: BookingCreate,
    user_id: str | None = Query(None, description="User ID"),
    service: BookingService = Depends(_get_booking_service),
) -> BookingResponse:
    """Create a new court booking."""
    try:
        booking = await service.create_booking(data, user_id or data.user_id or "current_user")
        return booking
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error creating booking")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/available/", response_model=bool)
async def check_availability(
    court_type: str = Query(..., description="Court type"),
    court_number: int = Query(..., ge=1, description="Court number"),
    start_time: datetime = Query(..., description="Start time (ISO 8601)"),
    end_time: datetime = Query(..., description="End time (ISO 8601)"),
    service: BookingService = Depends(_get_booking_service),
) -> bool:
    """Check if a court is available for the given time slot."""
    try:
        available = await service.check_availability(
            court_type, court_number, start_time, end_time
        )
        return available
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/", response_model=list[BookingResponse])
async def get_bookings(
    user_id: str = Query(..., description="User ID"),
    service: BookingService = Depends(_get_booking_service),
) -> list[BookingResponse]:
    """Get all bookings for a user."""
    try:
        return await service.get_user_bookings(user_id)
    except Exception as exc:
        logger.exception("Error fetching user bookings")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/availability", response_model=AvailabilityResponse)
async def get_day_availability(
    court_type: str = Query(..., description="Court type"),
    date: DateType = Query(..., description="Date"),
    service: BookingService = Depends(_get_booking_service),
) -> AvailabilityResponse:
    """Return available slots/courts for a court type on a specific date."""
    try:
        return await service.get_day_availability(court_type, date)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/user/{user_id}", response_model=list[BookingResponse])
async def get_user_bookings(
    user_id: str,
    service: BookingService = Depends(_get_booking_service),
) -> list[BookingResponse]:
    """Get all bookings for a user."""
    try:
        bookings = await service.get_user_bookings(user_id)
        return bookings
    except Exception as exc:
        logger.exception("Error fetching user bookings")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: str,
    service: BookingService = Depends(_get_booking_service),
) -> BookingResponse:
    """Get a booking by ID."""
    try:
        booking = await service.get_booking(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")
        return booking
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid booking ID") from exc


@router.patch("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(
    booking_id: str,
    service: BookingService = Depends(_get_booking_service),
) -> BookingResponse:
    """Cancel a booking."""
    try:
        result = await service.cancel_booking(booking_id)
        if not result:
            raise HTTPException(status_code=404, detail="Booking not found")
        return result
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error cancelling booking")
        raise HTTPException(status_code=500, detail="Internal server error") from exc
