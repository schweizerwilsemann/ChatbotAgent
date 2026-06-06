import logging
from datetime import datetime

from app.clients.payment_client import create_payment, verify_callback
from app.repositories.booking_repository import BookingRepository
from app.repositories.order_repository import OrderRepository
from app.repositories.payment_repository import PaymentRepository

logger = logging.getLogger(__name__)

VALID_PAYMENT_ORDER_TYPES = {"booking", "order"}


class PaymentService:
    def __init__(
        self,
        repo: PaymentRepository,
        booking_repo: BookingRepository | None = None,
        order_repo: OrderRepository | None = None,
    ) -> None:
        self._repo = repo
        self._booking_repo = booking_repo
        self._order_repo = order_repo

    async def create_payment(
        self,
        order_id: str,
        amount: int,
        description: str,
        return_url: str,
        ip_address: str,
        order_type: str = "booking",
    ) -> dict:
        if order_type not in VALID_PAYMENT_ORDER_TYPES:
            return {"success": False, "error": "Invalid payment order type"}

        existing = await self._repo.get_by_order_id(order_id)
        if existing and existing.status == "completed":
            return {"success": False, "error": "Order already paid"}

        if existing:
            if existing.amount != amount:
                return {
                    "success": False,
                    "error": "Payment amount does not match existing order payment",
                }
            if existing.status == "failed":
                await self._repo.create(
                    order_id=order_id,
                    amount=amount,
                    order_type=order_type,
                )
        else:
            await self._repo.create(
                order_id=order_id,
                amount=amount,
                order_type=order_type,
            )

        result = create_payment(
            order_id=order_id,
            amount=amount,
            order_info=description,
            return_url=return_url,
            ip_address=ip_address,
            order_type=order_type,
        )
        return result

    async def create_checkout_record(
        self,
        order_id: str,
        amount: int,
        order_type: str = "booking",
    ) -> tuple[bool, str | None]:
        if order_type not in VALID_PAYMENT_ORDER_TYPES:
            return False, "Invalid payment order type"

        existing = await self._repo.get_by_order_id(order_id)
        if existing and existing.status == "completed":
            return False, "Order already paid"
        if existing and existing.amount != amount:
            return False, "Payment amount does not match existing order payment"
        if not existing or existing.status == "failed":
            await self._repo.create(
                order_id=order_id,
                amount=amount,
                order_type=order_type,
            )
        return True, None

    async def confirm_external_payment(
        self,
        *,
        order_id: str,
        transaction_no: str | None,
        response_code: str,
        bank_code: str,
        is_success: bool,
        paid_at: datetime | None = None,
        order_type: str | None = None,
    ) -> None:
        txn = await self._repo.confirm(
            order_id=order_id,
            vnp_transaction_no=transaction_no,
            response_code=response_code,
            bank_code=bank_code,
            is_success=is_success,
            paid_at=paid_at,
        )
        resolved_type = order_type or (txn.order_type if txn else None)
        if resolved_type:
            payment_method = "stripe" if bank_code == "stripe" else "vnpay"
            status = f"paid_{payment_method}" if is_success else "failed"
            await self.mark_entity_payment_status(
                order_id=order_id,
                order_type=resolved_type,
                payment_status=status,
            )

    async def mark_entity_payment_status(
        self,
        *,
        order_id: str,
        order_type: str,
        payment_status: str,
    ) -> None:
        await self._set_entity_payment_status(
            order_id=order_id,
            order_type=order_type,
            payment_status=payment_status,
        )

    async def handle_callback(self, vnpay_params: dict[str, str]) -> dict:
        result = verify_callback(vnpay_params)

        if not result["is_valid"]:
            logger.warning("Invalid VNPay callback signature")
            return result

        transaction_no = result["transaction_no"]
        order_id = result["order_id"]
        paid_amount = result["amount"]

        txn = await self._repo.get_by_order_id(order_id)
        if not txn:
            logger.warning("VNPay callback for unknown order_id=%s", order_id)
            result["is_valid"] = False
            result["error"] = "order_not_found"
            return result

        if txn.amount != paid_amount:
            logger.warning(
                "VNPay amount mismatch for order=%s expected=%s actual=%s",
                order_id,
                txn.amount,
                paid_amount,
            )
            result["is_valid"] = False
            result["error"] = "amount_mismatch"
            return result

        if transaction_no:
            existing = await self._repo.get_by_vnp_transaction_no(transaction_no)
        else:
            existing = None

        if existing and existing.order_id == order_id:
            logger.info(
                "Duplicate callback for transaction %s, skipping", transaction_no
            )
        if txn.status in {"completed", "failed"}:
            logger.info("Duplicate callback for order %s, skipping", order_id)
            status = "paid_vnpay" if txn.status == "completed" else "failed"
            await self.mark_entity_payment_status(
                order_id=order_id,
                order_type=txn.order_type,
                payment_status=status,
            )
            result["already_processed"] = True
            return result

        if existing and existing.order_id != order_id:
            logger.warning(
                "VNPay transaction %s already belongs to another order", transaction_no
            )
            result["is_valid"] = False
            result["error"] = "duplicate_transaction_no"
            return result

        if txn.status in {"completed", "failed"}:
            if resolved_type:
                status = "paid_vnpay" if txn.status == "completed" else "failed"
                await self.mark_entity_payment_status(
                    order_id=order_id,
                    order_type=resolved_type,
                    payment_status=status,
                )
            result["already_processed"] = True
            return result

        await self.confirm_external_payment(
            order_id=order_id,
            transaction_no=transaction_no or None,
            response_code=result["response_code"],
            bank_code=result["bank_code"],
            is_success=result["is_success"],
            paid_at=datetime.utcnow(),
        )

        logger.info(
            "Payment callback recorded: order=%s txn=%s code=%s success=%s",
            order_id,
            transaction_no,
            result["response_code"],
            result["is_success"],
        )
        return result

    async def _set_entity_payment_status(
        self,
        *,
        order_id: str,
        order_type: str,
        payment_status: str,
    ) -> None:
        if order_type == "booking" and self._booking_repo:
            await self._booking_repo.update_payment_status(order_id, payment_status)
        elif order_type == "order" and self._order_repo:
            await self._order_repo.update_payment_status(order_id, payment_status)
