from datetime import datetime, timedelta
from unittest.mock import AsyncMock

import pytest

from app.schemas.booking import BookingCreate
from app.services.booking_service import BookingService


@pytest.mark.asyncio
async def test_booking_service_rejects_past_booking():
    """Past bookings should fail even if a model/tool sends an old year."""
    service = BookingService(AsyncMock())
    start_time = datetime.now() - timedelta(hours=1)
    end_time = start_time + timedelta(hours=2)

    with pytest.raises(ValueError, match="past"):
        await service.create_booking(
            BookingCreate(
                court_type="badminton",
                court_number=1,
                start_time=start_time.isoformat(),
                end_time=end_time.isoformat(),
            ),
            user_id="user123",
        )
