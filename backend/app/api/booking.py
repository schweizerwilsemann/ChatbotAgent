import logging
from datetime import date as DateType
from datetime import datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.repositories.booking_repository import BookingRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.order_repository import OrderRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.booking import (
    AvailabilityResponse,
    BookingBillResponse,
    BookingCreate,
    BookingResponse,
)
from app.services.order_service import OrderService
from app.services.booking_service import BookingService
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/booking", tags=["booking"])


async def _get_booking_service(
    session: AsyncSession = Depends(get_db),
) -> BookingService:
    repo = BookingRepository(session)
    venue_repo = VenueRepository(session)
    notification_service = NotificationService(
        NotificationRepository(session),
        venue_repo,
    )
    return BookingService(repo, notification_service, venue_repo)


@router.post("", response_model=BookingResponse, status_code=201)
async def create_booking(
    data: BookingCreate,
    _: None = Depends(rate_limit(limit=8, window_seconds=60, scope="booking")),
    user: User = Depends(get_current_user),
    service: BookingService = Depends(_get_booking_service),
) -> BookingResponse:
    """Create a new court booking."""
    try:
        booking = await service.create_booking(data, str(user.id), user=user)
        return booking
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error creating booking")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/active", response_model=BookingResponse | None)
async def get_active_booking(
    user: User = Depends(get_current_user),
    service: BookingService = Depends(_get_booking_service),
) -> BookingResponse | None:
    """Get the current user's active booking (now between start and end)."""
    try:
        return await service.get_active_user_booking(str(user.id))
    except Exception as exc:
        logger.exception("Error fetching active booking")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/available/", response_model=bool)
async def check_availability(
    court_type: str = Query(..., description="Court type"),
    court_number: int = Query(..., ge=1, description="Court number"),
    resource_id: str | None = Query(None, description="Table/court resource ID"),
    start_time: datetime = Query(..., description="Start time (ISO 8601)"),
    end_time: datetime = Query(..., description="End time (ISO 8601)"),
    service: BookingService = Depends(_get_booking_service),
) -> bool:
    """Check if a court is available for the given time slot."""
    try:
        available = await service.check_availability(
            court_type,
            court_number,
            start_time,
            end_time,
            resource_id=resource_id,
        )
        return available
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("", response_model=list[BookingResponse])
async def get_bookings(
    user_id: str | None = Query(None, description="User ID"),
    limit: int = Query(10, ge=1, le=100, description="Maximum rows to return"),
    offset: int = Query(0, ge=0, description="Rows to skip"),
    user: User = Depends(get_current_user),
    service: BookingService = Depends(_get_booking_service),
) -> list[BookingResponse]:
    """Get all bookings for a user."""
    try:
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        target_user_id = (
            user_id if role_value in {"STAFF", "ADMIN"} and user_id else str(user.id)
        )
        return await service.get_user_bookings(
            target_user_id,
            limit=limit,
            offset=offset,
        )
    except Exception as exc:
        logger.exception("Error fetching user bookings")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/bills", response_model=list[BookingBillResponse])
async def get_booking_bills(
    limit: int = Query(10, ge=1, le=100, description="Maximum rows to return"),
    offset: int = Query(0, ge=0, description="Rows to skip"),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[BookingBillResponse]:
    """Get combined court + menu bills for the current customer."""
    try:
        booking_repo = BookingRepository(session)
        order_repo = OrderRepository(session)
        bookings = await booking_repo.get_by_user_id(
            str(user.id),
            limit=limit,
            offset=offset,
        )
        bills = []
        for booking in bookings:
            orders = await order_repo.get_for_booking(booking)
            bills.append(_booking_bill_response(booking, orders))
        return bills
    except Exception as exc:
        logger.exception("Error fetching booking bills")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/{booking_id}/bill", response_model=BookingBillResponse)
async def get_booking_bill(
    booking_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> BookingBillResponse:
    """Get the combined court + menu bill for one booking."""
    try:
        booking_repo = BookingRepository(session)
        order_repo = OrderRepository(session)
        booking = await booking_repo.get_by_id(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")
        if booking.user_id != str(user.id):
            raise HTTPException(
                status_code=403,
                detail="Cannot access another user's booking bill",
            )
        orders = await order_repo.get_for_booking(booking)
        return _booking_bill_response(booking, orders)
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid booking ID") from exc
    except Exception as exc:
        logger.exception("Error fetching booking bill")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/availability", response_model=AvailabilityResponse)
async def get_day_availability(
    court_type: str = Query(..., description="Court type"),
    venue_id: str | None = Query(None, description="Venue ID"),
    date: DateType = Query(..., description="Date"),
    service: BookingService = Depends(_get_booking_service),
) -> AvailabilityResponse:
    """Return available slots/courts for a court type on a specific date."""
    try:
        return await service.get_day_availability(court_type, date, venue_id=venue_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/user/{user_id}", response_model=list[BookingResponse])
async def get_user_bookings(
    user_id: str,
    limit: int = Query(10, ge=1, le=100, description="Maximum rows to return"),
    offset: int = Query(0, ge=0, description="Rows to skip"),
    user: User = Depends(get_current_user),
    service: BookingService = Depends(_get_booking_service),
) -> list[BookingResponse]:
    """Get all bookings for a user."""
    try:
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        if role_value not in {"STAFF", "ADMIN"} and user_id != str(user.id):
            raise HTTPException(
                status_code=403, detail="Cannot access another user's bookings"
            )
        bookings = await service.get_user_bookings(
            user_id,
            limit=limit,
            offset=offset,
        )
        return bookings
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error fetching user bookings")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: str,
    user: User = Depends(get_current_user),
    service: BookingService = Depends(_get_booking_service),
) -> BookingResponse:
    """Get a booking by ID."""
    try:
        booking = await service.get_booking(booking_id)
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        if role_value not in {"STAFF", "ADMIN"} and booking.user_id != str(user.id):
            raise HTTPException(
                status_code=403, detail="Cannot access another user's booking"
            )
        return booking
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid booking ID") from exc


@router.patch("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(
    booking_id: str,
    user: User = Depends(get_current_user),
    service: BookingService = Depends(_get_booking_service),
) -> BookingResponse:
    """Cancel a booking."""
    try:
        existing = await service.get_booking(booking_id)
        if not existing:
            raise HTTPException(status_code=404, detail="Booking not found")
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        if role_value not in {"STAFF", "ADMIN"} and existing.user_id != str(user.id):
            raise HTTPException(
                status_code=403, detail="Cannot cancel another user's booking"
            )
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


def _booking_bill_response(booking, orders) -> BookingBillResponse:
    order_total = sum((order.total_price for order in orders), Decimal("0"))
    booking_total = (
        Decimal(str(booking.total_price)) if booking.total_price is not None else None
    )
    return BookingBillResponse(
        booking=BookingService._to_response(booking),
        orders=[OrderService._to_response(order) for order in orders],
        order_total=order_total,
        booking_total=booking_total,
        grand_total=order_total + (booking_total or Decimal("0")),
    )
