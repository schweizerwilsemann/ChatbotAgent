import logging

import grpc

from app.core.config import settings
from grpc_client import payment_pb2, payment_pb2_grpc

logger = logging.getLogger(__name__)


def _get_channel() -> grpc.Channel:
    target = f"{settings.PAYMENT_SERVICE_HOST}:{settings.PAYMENT_SERVICE_PORT}"
    return grpc.insecure_channel(target)


def _get_metadata() -> list[tuple[str, str]]:
    if not settings.INTERNAL_API_KEY:
        raise RuntimeError("INTERNAL_API_KEY is required for payment gRPC calls")
    return [("x-internal-api-key", settings.INTERNAL_API_KEY)]


def create_payment(
    order_id: str,
    amount: int,
    order_info: str,
    return_url: str,
    ip_address: str,
    order_type: str = "booking",
) -> dict:
    with _get_channel() as channel:
        stub = payment_pb2_grpc.PaymentServiceStub(channel)
        request = payment_pb2.CreatePaymentRequest(
            order_id=order_id,
            amount=amount,
            order_info=order_info,
            return_url=return_url,
            ip_address=ip_address,
            order_type=order_type,
        )
        response = stub.CreatePayment(request, metadata=_get_metadata(), timeout=10)
        return {
            "success": response.success,
            "payment_url": response.payment_url,
            "error": response.error_message,
        }


def verify_callback(vnpay_params: dict[str, str]) -> dict:
    with _get_channel() as channel:
        stub = payment_pb2_grpc.PaymentServiceStub(channel)
        request = payment_pb2.VerifyCallbackRequest(vnpay_params=vnpay_params)
        response = stub.VerifyCallback(request, metadata=_get_metadata(), timeout=10)
        return {
            "is_valid": response.is_valid,
            "is_success": response.is_success,
            "transaction_no": response.transaction_no,
            "order_id": response.order_id,
            "amount": response.amount,
            "response_code": response.response_code,
            "bank_code": response.bank_code,
        }


def query_transaction(order_id: str, create_date: str, ip_address: str) -> dict:
    with _get_channel() as channel:
        stub = payment_pb2_grpc.PaymentServiceStub(channel)
        request = payment_pb2.QueryTransactionRequest(
            order_id=order_id,
            create_date=create_date,
            ip_address=ip_address,
        )
        response = stub.QueryTransaction(request, metadata=_get_metadata(), timeout=15)
        return {
            "success": response.success,
            "transaction_no": response.transaction_no,
            "transaction_type": response.transaction_type,
            "pay_date": response.pay_date,
            "response_code": response.response_code,
            "message": response.message,
        }
