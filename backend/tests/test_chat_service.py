from app.services.chat_service import ChatService


def test_enrich_message_includes_current_time_context():
    enriched = ChatService._enrich_message_with_context(
        "đặt sân 3h chiều nay",
        {
            "venue_id": "venue-1",
            "venue_name": "Nhà thi đấu Cầu lông Bình Thạnh",
            "venue_timezone": "Asia/Ho_Chi_Minh",
            "court_type": "badminton",
            "court_type_name": "cầu lông",
        },
    )

    assert "current_date=" in enriched
    assert "current_time=" in enriched
    assert "timezone=Asia/Ho_Chi_Minh" in enriched
    assert "hôm nay=" in enriched
    assert "đặt sân 3h chiều nay" in enriched
