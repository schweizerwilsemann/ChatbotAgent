import logging
import unicodedata

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.repositories.payment_repository import PaymentRepository
from app.schemas.payment import (
    CreatePaymentRequest,
    CreatePaymentResponse,
    QueryPaymentResponse,
)
from app.services.payment_service import PaymentService
from app.clients.payment_client import query_transaction


def _strip_diacritics(text: str) -> str:
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c))

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/payment", tags=["payment"])


async def _get_payment_service(
    session: AsyncSession = Depends(get_db),
) -> PaymentService:
    repo = PaymentRepository(session)
    return PaymentService(repo)


@router.post("/create", response_model=CreatePaymentResponse)
async def create_payment_url(
    body: CreatePaymentRequest,
    request: Request,
    _: None = Depends(rate_limit(limit=5, window_seconds=60, scope="payment")),
    user: User = Depends(get_current_user),
    service: PaymentService = Depends(_get_payment_service),
) -> CreatePaymentResponse:
    try:
        ip = request.client.host if request.client else "127.0.0.1"
        base_url = str(request.base_url).rstrip("/")
        return_url = f"{base_url}/api/payment/callback"

        result = await service.create_payment(
            order_id=body.order_id,
            amount=body.amount,
            description=_strip_diacritics(body.description),
            return_url=return_url,
            ip_address=ip,
            order_type=body.order_type,
        )
        if not result["success"]:
            raise HTTPException(status_code=500, detail=result["error"])
        return CreatePaymentResponse(
            success=True, payment_url=result["payment_url"]
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Error creating payment")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/callback")
async def payment_callback(
    request: Request,
    service: PaymentService = Depends(_get_payment_service),
):
    params = dict(request.query_params)
    result = await service.handle_callback(params)

    if not result.get("is_valid"):
        reason = result.get("error") or "invalid_signature"
        return RedirectResponse(url=f"/payment/failed?reason={reason}")

    order_id = result.get("order_id", "")
    if result.get("already_processed") or result.get("is_success"):
        return RedirectResponse(url=f"/payment/success?order={order_id}")

    response_code = result.get("response_code", "unknown")
    return RedirectResponse(url=f"/payment/failed?code={response_code}")


@router.get("/query", response_model=QueryPaymentResponse)
async def query_payment_transaction(
    order_id: str,
    create_date: str,
    request: Request,
    _: None = Depends(rate_limit(limit=10, window_seconds=60, scope="payment_query")),
    user: User = Depends(get_current_user),
) -> QueryPaymentResponse:
    ip = request.client.host if request.client else "127.0.0.1"
    result = query_transaction(order_id=order_id, create_date=create_date, ip_address=ip)
    return QueryPaymentResponse(**result)
