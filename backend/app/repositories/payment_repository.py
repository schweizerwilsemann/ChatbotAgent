import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payment import PaymentTransaction


class PaymentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        order_id: str,
        amount: int,
        order_type: str = "booking",
    ) -> PaymentTransaction:
        txn = PaymentTransaction(
            id=uuid.uuid4(),
            order_id=order_id,
            amount=amount,
            order_type=order_type,
            status="pending",
        )
        self._session.add(txn)
        await self._session.flush()
        return txn

    async def get_by_order_id(self, order_id: str) -> PaymentTransaction | None:
        stmt = (
            select(PaymentTransaction)
            .where(PaymentTransaction.order_id == order_id)
            .order_by(PaymentTransaction.created_at.desc())
            .limit(1)
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_vnp_transaction_no(
        self, vnp_transaction_no: str
    ) -> PaymentTransaction | None:
        stmt = select(PaymentTransaction).where(
            PaymentTransaction.vnp_transaction_no == vnp_transaction_no
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def confirm(
        self,
        order_id: str,
        vnp_transaction_no: str | None,
        response_code: str,
        bank_code: str,
        is_success: bool,
        paid_at: datetime | None = None,
    ) -> PaymentTransaction | None:
        txn = await self.get_by_order_id(order_id)
        if not txn:
            return None
        txn.status = "completed" if is_success else "failed"
        if vnp_transaction_no:
            txn.vnp_transaction_no = vnp_transaction_no
        txn.response_code = response_code
        txn.bank_code = bank_code
        txn.paid_at = paid_at or datetime.utcnow()
        await self._session.flush()
        return txn

    async def get_by_id(self, txn_id: str) -> PaymentTransaction | None:
        stmt = select(PaymentTransaction).where(
            PaymentTransaction.id == uuid.UUID(txn_id)
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()
