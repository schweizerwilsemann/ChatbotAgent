import json
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from app.agent.tools.book_court import book_court
from app.agent.tools.call_staff import call_staff
from app.agent.tools.query_faq import query_knowledge, set_neo4j_client


@pytest.mark.asyncio
async def test_query_knowledge_tool_no_client():
    """Test query_knowledge returns error when Neo4j client is not set."""
    set_neo4j_client(None)

    result = await query_knowledge.ainvoke("billiards rules")

    assert "chưa được kết nối" in result


@pytest.mark.asyncio
async def test_query_knowledge_tool_with_results():
    """Test query_knowledge returns formatted results from Neo4j."""
    mock_client = AsyncMock()
    mock_client.execute_query.return_value = [
        {
            "title": "Luật bida 8 bi",
            "content": "Mục tiêu là đánh bóng vào lỗ.",
            "sport": "billiards",
            "labels": ["FAQ"],
            "relationship": "RELATED_TO",
            "related_title": "Kỹ thuật cơ bản",
            "related_content": "Cầm cơ đúng cách.",
            "score": 0.95,
        }
    ]
    set_neo4j_client(mock_client)

    result = await query_knowledge.ainvoke("luật bida")

    assert "Luật bida 8 bi" in result
    assert "billiards" in result


@pytest.mark.asyncio
@patch("app.agent.tools.book_court.async_session_factory")
@patch("app.agent.tools.book_court.BookingRepository")
@patch("app.agent.tools.book_court.BookingService")
async def test_book_court_tool_success(
    mock_service_cls, mock_repo_cls, mock_session_factory
):
    """Test book_court returns success message when booking succeeds."""
    mock_session = AsyncMock()
    mock_session_factory.return_value.__aenter__ = AsyncMock(return_value=mock_session)
    mock_session_factory.return_value.__aexit__ = AsyncMock(return_value=False)

    mock_repo = MagicMock()
    mock_repo_cls.return_value = mock_repo

    mock_service = AsyncMock()
    mock_service.check_availability.return_value = True
    mock_booking = MagicMock()
    mock_booking.id = "booking-123"
    mock_booking.status = "confirmed"
    mock_service.create_booking.return_value = mock_booking
    mock_service_cls.return_value = mock_service

    result = await book_court.ainvoke(
        {
            "court_type": "billiards",
            "court_number": 1,
            "start_time": "2024-01-15T14:00:00",
            "end_time": "2024-01-15T16:00:00",
            "notes": "Test",
        }
    )

    assert "Đặt sân thành công" in result
    assert "booking-123" in result


@pytest.mark.asyncio
async def test_book_court_tool_invalid_time():
    """Test book_court returns error for invalid time format."""
    result = await book_court.ainvoke(
        {
            "court_type": "billiards",
            "court_number": 1,
            "start_time": "invalid-time",
            "end_time": "2024-01-15T16:00:00",
        }
    )

    assert "không hợp lệ" in result


@pytest.mark.asyncio
@patch("app.agent.tools.call_staff.redis_client")
async def test_call_staff_tool_success(mock_redis):
    """Test call_staff stores notification in Redis successfully."""
    mock_redis.set = AsyncMock()
    mock_redis.client = AsyncMock()
    mock_redis.client.publish = AsyncMock()

    result = await call_staff.ainvoke(
        {"message": "Cần thêm phấn bida", "table_number": 5}
    )

    assert "Đã gọi nhân viên thành công" in result
    assert "Cần thêm phấn bida" in result
    assert "bàn số 5" in result
    mock_redis.set.assert_awaited()


@pytest.mark.asyncio
@patch("app.agent.tools.call_staff.redis_client")
async def test_call_staff_tool_no_table(mock_redis):
    """Test call_staff works without specifying table number."""
    mock_redis.set = AsyncMock()
    mock_redis.client = AsyncMock()
    mock_redis.client.publish = AsyncMock()

    result = await call_staff.ainvoke({"message": "Sân bị hư hỏng", "table_number": 0})

    assert "Đã gọi nhân viên thành công" in result
    assert "Sân bị hư hỏng" in result
    assert "bàn số" not in result
