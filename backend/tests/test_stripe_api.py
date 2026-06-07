from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.api.stripe import confirm_payment_intent


@pytest.mark.asyncio
async def test_confirm_payment_intent_marks_entity_paid():
    txn = SimpleNamespace(
        order_id="booking-1",
        order_type="booking",
        amount=150000,
        status="pending",
    )
    service = SimpleNamespace(
        _repo=SimpleNamespace(get_by_order_id=AsyncMock(return_value=txn)),
        confirm_external_payment=AsyncMock(),
        mark_entity_payment_status=AsyncMock(),
    )
    user = SimpleNamespace(id="user-1")

    with patch("app.api.stripe.stripe.PaymentIntent.retrieve") as retrieve:
        retrieve.return_value = {
            "id": "pi_123",
            "status": "succeeded",
            "amount": 150000,
            "amount_received": 150000,
            "metadata": {
                "order_id": "booking-1",
                "order_type": "booking",
                "user_id": "user-1",
            },
        }

        result = await confirm_payment_intent(
            {"payment_intent_id": "pi_123", "order_id": "booking-1"},
            _=None,
            user=user,
            service=service,
        )

    assert result["payment_status"] == "paid_stripe"
    service.confirm_external_payment.assert_awaited_once_with(
        order_id="booking-1",
        transaction_no="pi_123",
        response_code="00",
        bank_code="stripe",
        is_success=True,
        order_type="booking",
    )
