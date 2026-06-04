import logging

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.repositories.payment_repository import PaymentRepository
from app.services.payment_service import PaymentService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/stripe", tags=["stripe"])

stripe.api_key = settings.STRIPE_SECRET_KEY


async def _get_payment_service(
    session: AsyncSession = Depends(get_db),
) -> PaymentService:
    repo = PaymentRepository(session)
    return PaymentService(repo)


@router.post("/create-checkout")
async def create_stripe_checkout(
    body: dict,
    request: Request,
    _: None = Depends(rate_limit(limit=10, window_seconds=60, scope="stripe")),
    user: User = Depends(get_current_user),
    service: PaymentService = Depends(_get_payment_service),
) -> dict:
    order_id = body.get("order_id")
    amount = body.get("amount")  # in VND
    description = body.get("description", "Payment")

    if not order_id or not amount:
        raise HTTPException(status_code=400, detail="order_id and amount are required")

    existing = await service._repo.get_by_order_id(order_id)
    if existing and existing.status == "completed":
        raise HTTPException(status_code=400, detail="Order already paid")

    if not existing:
        await service._repo.create(
            order_id=order_id,
            amount=amount,
            order_type="booking",
        )

    base_url = str(request.base_url).rstrip("/")
    success_url = f"{base_url}/api/stripe/success?order_id={order_id}"
    cancel_url = f"{base_url}/api/stripe/cancel?order_id={order_id}"

    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[
                {
                    "price_data": {
                        "currency": "vnd",
                        "product_data": {
                            "name": description,
                        },
                        "unit_amount": int(amount),
                    },
                    "quantity": 1,
                }
            ],
            mode="payment",
            success_url=success_url,
            cancel_url=cancel_url,
            metadata={
                "order_id": order_id,
                "user_id": str(user.id),
            },
        )

        return {
            "checkout_url": session.url,
            "session_id": session.id,
        }
    except stripe.error.StripeError as e:
        logger.exception("Stripe error")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/success")
async def stripe_success(order_id: str):
    from fastapi.responses import RedirectResponse

    return RedirectResponse(url=f"/payment/success?order={order_id}")


@router.get("/cancel")
async def stripe_cancel(order_id: str):
    from fastapi.responses import RedirectResponse

    return RedirectResponse(url=f"/payment/failed?code=cancelled")


@router.post("/webhook")
async def stripe_webhook(
    request: Request,
    service: PaymentService = Depends(_get_payment_service),
):
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")

    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        order_id = session["metadata"]["order_id"]

        txn = await service._repo.get_by_order_id(order_id)
        if txn and txn.status != "completed":
            await service._repo.confirm(
                order_id=order_id,
                vnp_transaction_no=session.get("payment_intent"),
                response_code="00",
                bank_code="stripe",
                is_success=True,
            )
            logger.info("Stripe payment confirmed: order=%s", order_id)

    return {"status": "ok"}


@router.get("/config")
async def get_stripe_config() -> dict:
    return {
        "publishable_key": settings.STRIPE_PUBLISHABLE_KEY,
    }
