import pytest

from app.agent.context import current_chat_context
from app.agent.order_confirmation import (
    is_affirmative_message,
    order_creation_is_confirmed,
    order_payload_matches_confirmation,
)
from app.agent.simple_agent import SimpleVenueAgent
from app.agent.tools.order_menu_items import order_menu_items


def test_order_confirmation_requires_summary_with_notes():
    context = {
        "_current_user_message": "Đồng ý",
        "_session_history": [
            {"role": "user", "content": "Cho tôi một cà phê sữa"},
            {
                "role": "assistant",
                "content": (
                    "Bạn có yêu cầu đặc biệt hoặc ghi chú gì cho món không ạ?"
                ),
            },
            {"role": "user", "content": "Ít sữa, đá riêng"},
            {
                "role": "assistant",
                "content": (
                    "Mình xin tóm tắt: 1 cà phê sữa. "
                    "Ghi chú: ít sữa, đá riêng. "
                    "Bạn xác nhận muốn đặt món này đúng không ạ?"
                ),
            },
            {"role": "user", "content": "Đồng ý"},
        ],
    }

    assert order_creation_is_confirmed(context) is True


def test_order_confirmation_rejects_skipped_note_question():
    context = {
        "_current_user_message": "Đồng ý",
        "_session_history": [
            {"role": "user", "content": "Cho tôi một cà phê sữa"},
            {
                "role": "assistant",
                "content": (
                    "Mình xin tóm tắt: 1 cà phê sữa. Ghi chú: Không có. "
                    "Bạn xác nhận muốn đặt món này đúng không ạ?"
                ),
            },
            {"role": "user", "content": "Đồng ý"},
        ],
    }

    assert order_creation_is_confirmed(context) is False


def test_order_confirmation_rejects_changes_in_affirmative_message():
    assert is_affirmative_message("Đồng ý nhưng đổi thành ít đá") is False


def test_order_payload_must_match_confirmed_quantity_and_notes():
    context = {
        "_session_history": [
            {
                "role": "assistant",
                "content": (
                    "Mình xin tóm tắt: 1 cà phê sữa. "
                    "Ghi chú: ít sữa, đá riêng. "
                    "Bạn xác nhận muốn đặt món này đúng không ạ?"
                ),
            }
        ]
    }

    assert order_payload_matches_confirmation(
        context,
        [{"item_name": "Cà phê sữa", "quantity": 1}],
        "Ít sữa, đá riêng",
    )
    assert not order_payload_matches_confirmation(
        context,
        [{"item_name": "Cà phê sữa", "quantity": 2}],
        "Ít sữa, đá riêng",
    )
    assert not order_payload_matches_confirmation(
        context,
        [{"item_name": "Cà phê sữa", "quantity": 1}],
        "Nhiều sữa",
    )


@pytest.mark.asyncio
async def test_order_tool_does_not_create_before_confirmation():
    token = current_chat_context.set(
        {
            "_current_user_message": "Cho tôi một cà phê sữa",
            "_session_history": [
                {"role": "user", "content": "Cho tôi một cà phê sữa"}
            ],
        }
    )
    try:
        result = await order_menu_items.ainvoke(
            {
                "items": '[{"item_name": "Cà phê sữa", "quantity": 1}]',
                "notes": "",
            }
        )
    finally:
        current_chat_context.reset(token)

    assert "CHƯA TẠO ĐƠN" in result
    assert "yêu cầu đặc biệt" in result


def test_simple_agent_recovers_pending_order_and_notes_from_history():
    pending = SimpleVenueAgent._pending_order_from_history(
        [
            {
                "role": "user",
                "content": (
                    "[Ngữ cảnh hiện tại: venue đã chọn]\n"
                    "Cho tôi một cà phê sữa"
                ),
            },
            {
                "role": "assistant",
                "content": (
                    "Bạn có yêu cầu đặc biệt hoặc ghi chú gì cho món không ạ?"
                ),
            },
            {"role": "user", "content": "Ít sữa, đá riêng"},
            {
                "role": "assistant",
                "content": (
                    "Mình xin tóm tắt: 1 Cà phê sữa. "
                    "Ghi chú: Ít sữa, đá riêng. "
                    "Bạn xác nhận muốn đặt món này đúng không ạ?"
                ),
            },
            {"role": "user", "content": "Đồng ý"},
        ]
    )

    assert pending == ("Cho tôi một cà phê sữa", "Ít sữa, đá riêng")


def test_simple_agent_matches_cafe_alias_quantity():
    message = "Cho tôi 2 cafe sữa"
    item_name = "Cà phê sữa"

    assert SimpleVenueAgent._normalize_menu_text(item_name) in (
        SimpleVenueAgent._normalize_menu_text(message)
    )
    assert SimpleVenueAgent._extract_quantity_near_item(message, item_name) == 2
