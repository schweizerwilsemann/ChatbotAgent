import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.order import Order, OrderItem


class OrderRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        user_id: str,
        table_number: int,
        items_data: list[dict],
        menu_prices: dict[str, Decimal],
        notes: str = "",
    ) -> Order:
        order = Order(
            id=uuid.uuid4(),
            user_id=user_id,
            table_number=table_number,
            status="pending",
            total_price=Decimal("0"),
            notes=notes or None,
        )
        self._session.add(order)
        await self._session.flush()

        total = Decimal("0")
        for item_data in items_data:
            item_name = item_data["item_name"]
            quantity = item_data["quantity"]
            unit_price = menu_prices.get(item_name.lower(), Decimal("0"))
            line_total = unit_price * quantity
            total += line_total

            order_item = OrderItem(
                id=uuid.uuid4(),
                order_id=order.id,
                item_name=item_name,
                quantity=quantity,
                unit_price=unit_price,
            )
            self._session.add(order_item)

        order.total_price = total
        await self._session.flush()
        # Eagerly load the items relationship so _to_response can access
        # order.items synchronously without hitting MissingGreenlet.
        await self._session.refresh(order, ["items"])
        return order

    async def get_by_id(self, order_id: str) -> Order | None:
        try:
            order_uuid = uuid.UUID(order_id)
        except ValueError:
            return None

        stmt = (
            select(Order)
            .options(selectinload(Order.items))
            .where(Order.id == order_uuid)
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: str) -> list[Order]:
        stmt = (
            select(Order)
            .options(selectinload(Order.items))
            .where(Order.user_id == user_id)
            .order_by(Order.created_at.desc())
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def update_status(self, order_id: str, status: str) -> Order | None:
        order = await self.get_by_id(order_id)
        if not order:
            return None
        order.status = status
        await self._session.flush()
        return order
