import json
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from app.agent.tools.book_court import book_court
from app.agent.tools.call_staff import call_staff
from app.agent.context import current_chat_context
from app.agent.tools.query_faq import _clean_query, query_knowledge, set_neo4j_client


@pytest.mark.asyncio
async def test_query_knowledge_tool_no_client():
    """Test query_knowledge returns error when Neo4j client is not set."""
    set_neo4j_client(None)

    result = await query_knowledge.ainvoke("billiards rules")

    assert "chưa được kết nối" in result


@pytest.mark.asyncio
@patch("app.agent.tools.query_faq.redis_client")
async def test_query_knowledge_tool_with_results(mock_redis):
    """Test query_knowledge returns formatted results from Neo4j."""
    mock_client = AsyncMock()
    mock_redis.get = AsyncMock(return_value=None)
    mock_redis.set = AsyncMock()

    async def execute_query(query, params):
        if "db.index.fulltext.queryNodes" in query:
            return [
                {
                    "node_id": "rule-1",
                    "name": "Luật bida 8 bi",
                    "type": "Rule",
                    "description": "Mục tiêu là đánh bóng vào lỗ.",
                    "source": "WPA",
                    "score": 0.95,
                }
            ]
        if "MATCH path" in query:
            return [
                {
                    "seed_id": "rule-1",
                    "related_name": "Bida",
                    "related_type": "Sport",
                    "related_description": "Môn thể thao bida.",
                    "related_source": "WPA",
                    "relationship_path": ["THUOC"],
                    "distance": 1,
                }
            ]
        return []

    mock_client.execute_query.side_effect = execute_query
    set_neo4j_client(mock_client)

    result = await query_knowledge.ainvoke("luật bida")

    assert "Luật bida 8 bi" in result
    assert "[Rule]" in result
    assert "THUOC (1 bước): Bida" in result
    assert "Nguồn: WPA" in result


def test_clean_query_strips_internal_context_and_prefers_current_user_message():
    token = current_chat_context.set(
        {"_current_user_message": "luật giao bóng cầu lông"}
    )
    try:
        cleaned = _clean_query(
            "[Ngữ cảnh hiện tại: current_datetime=2026-06-16T13:38:16+07:00; "
            "venue_name=Nhà thi đấu Cầu lông]\nluật giao bóng cầu lông"
        )
    finally:
        current_chat_context.reset(token)

    assert cleaned == "luật giao bóng cầu lông"


def test_clean_query_appends_context_sport_when_question_omits_sport():
    token = current_chat_context.set(
        {
            "_current_user_message": "luật giao bóng",
            "court_type": "badminton",
            "court_type_name": "cầu lông",
            "venue_name": "Nhà thi đấu Cầu lông",
        }
    )
    try:
        cleaned = _clean_query("luật giao bóng")
    finally:
        current_chat_context.reset(token)

    assert cleaned == "luật giao bóng cầu lông"


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
