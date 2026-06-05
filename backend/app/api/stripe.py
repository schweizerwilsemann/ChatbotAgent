import logging

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.repositories.booking_repository import BookingRepository
from app.repositories.order_repository import OrderRepository
from app.repositories.payment_repository import PaymentRepository
from app.repositories.user_repository import UserRepository
from app.services.payment_service import PaymentService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/stripe", tags=["stripe"])

stripe.api_key = settings.STRIPE_SECRET_KEY


async def _get_payment_service(
    session: AsyncSession = Depends(get_db),
) -> PaymentService:
    repo = PaymentRepository(session)
    booking_repo = BookingRepository(session)
    order_repo = OrderRepository(session)
    return PaymentService(repo, booking_repo, order_repo)


@router.post("/create-checkout")
async def create_stripe_checkout(
    body: dict,
    request: Request,
    _: None = Depends(rate_limit(limit=10, window_seconds=60, scope="stripe")),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    service: PaymentService = Depends(_get_payment_service),
) -> dict:
    order_id = body.get("order_id")
    amount = body.get("amount")  # in VND
    description = body.get("description", "Payment")
    order_type = body.get("order_type", "booking")

    if not order_id or not amount:
        raise HTTPException(status_code=400, detail="order_id and amount are required")

    try:
        amount_int = int(amount)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="amount must be an integer")

    ok, error = await service.create_checkout_record(
        order_id=order_id,
        amount=amount_int,
        order_type=order_type,
    )
    if not ok:
        raise HTTPException(status_code=400, detail=error or "Cannot create payment")

    stripe_customer_id = user.stripe_customer_id
    if not stripe_customer_id:
        try:
            customer = stripe.Customer.create(
                name=user.name,
                email=user.email,
                phone=user.phone,
                metadata={"user_id": str(user.id)},
            )
            stripe_customer_id = customer.id
            user_repo = UserRepository(session)
            await user_repo.update_stripe_customer_id(str(user.id), stripe_customer_id)
        except stripe.error.StripeError as e:
            logger.exception("Stripe customer creation error")
            raise HTTPException(status_code=500, detail=str(e))

    base_url = str(request.base_url).rstrip("/")
    success_url = f"{base_url}/api/stripe/success?order_id={order_id}"
    cancel_url = f"{base_url}/api/stripe/cancel?order_id={order_id}"

    try:
        checkout_session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[
                {
                    "price_data": {
                        "currency": "vnd",
                        "product_data": {
                            "name": description,
                        },
                        "unit_amount": amount_int,
                    },
                    "quantity": 1,
                }
            ],
            mode="payment",
            customer=stripe_customer_id,
            saved_payment_method_options={
                "payment_method_save": "enabled",
            },
            success_url=success_url,
            cancel_url=cancel_url,
            metadata={
                "order_id": order_id,
                "order_type": order_type,
                "user_id": str(user.id),
            },
        )

        return {
            "checkout_url": checkout_session.url,
            "session_id": checkout_session.id,
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
        metadata = session.get("metadata") or {}
        order_id = metadata.get("order_id")
        order_type = metadata.get("order_type")
        if not order_id:
            logger.warning("Stripe checkout completed without order_id metadata")
            return {"status": "ok"}

        txn = await service._repo.get_by_order_id(order_id)
        if txn and txn.status != "completed":
            await service.confirm_external_payment(
                order_id=order_id,
                transaction_no=session.get("payment_intent"),
                response_code="00",
                bank_code="stripe",
                is_success=True,
                order_type=order_type,
            )
            logger.info("Stripe payment confirmed: order=%s", order_id)
        elif txn and txn.status == "completed":
            await service.mark_entity_payment_status(
                order_id=order_id,
                order_type=order_type or txn.order_type,
                payment_status="paid_stripe",
            )

    return {"status": "ok"}


@router.get("/config")
async def get_stripe_config() -> dict:
    return {
        "publishable_key": settings.STRIPE_PUBLISHABLE_KEY,
    }
