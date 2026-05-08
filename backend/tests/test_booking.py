import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from app.models.booking import Booking
from app.repositories.booking_repository import BookingRepository


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.execute = AsyncMock()
    session.add = MagicMock()
    session.flush = AsyncMock()
    return session


@pytest.fixture
def repo(mock_session):
    return BookingRepository(mock_session)


@pytest.mark.asyncio
async def test_create_booking(repo, mock_session):
    """Test creating a new booking."""
    booking_id = uuid.uuid4()
    mock_booking = MagicMock(spec=Booking)
    mock_booking.id = booking_id
    mock_booking.court_type = "billiards"
    mock_booking.court_number = 1
    mock_booking.status = "confirmed"

    result = await repo.create(
        user_id="user123",
        court_type="billiards",
        court_number=1,
        start_time=datetime(2024, 1, 15, 14, 0, 0, tzinfo=timezone.utc),
        end_time=datetime(2024, 1, 15, 16, 0, 0, tzinfo=timezone.utc),
        notes="Test booking",
    )

    mock_session.add.assert_called_once()
    mock_session.flush.assert_awaited()


@pytest.mark.asyncio
async def test_check_availability(repo, mock_session):
    """Test checking court availability (no conflict)."""
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_session.execute.return_value = mock_result

    available = await repo.check_conflict(
        court_type="billiards",
        court_number=1,
        start_time=datetime(2024, 1, 15, 14, 0, 0, tzinfo=timezone.utc),
        end_time=datetime(2024, 1, 15, 16, 0, 0, tzinfo=timezone.utc),
    )

    assert available is False
    mock_session.execute.assert_awaited()


@pytest.mark.asyncio
async def test_cancel_booking(repo, mock_session):
    """Test cancelling an existing booking."""
    booking_id = uuid.uuid4()
    mock_booking = MagicMock(spec=Booking)
    mock_booking.id = booking_id
    mock_booking.status = "confirmed"

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_booking
    mock_session.execute.return_value = mock_result

    result = await repo.cancel(str(booking_id))

    assert result is not None
    assert result.status == "cancelled"
    mock_session.flush.assert_awaited()
