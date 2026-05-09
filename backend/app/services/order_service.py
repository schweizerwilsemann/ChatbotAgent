import logging
from decimal import Decimal

from app.api.menu import MENU_PRICES
from app.repositories.order_repository import OrderRepository
from app.schemas.order import OrderCreate, OrderItemResponse, OrderResponse

logger = logging.getLogger(__name__)


class OrderService:
    def __init__(self, repo: OrderRepository) -> None:
        self._repo = repo

    async def create_order(self, data: OrderCreate) -> OrderResponse:
        """Create a new order, calculating total price from the menu."""
        if not data.items:
            raise ValueError("Order must contain at least one item")

        items_data = []
        for item in data.items:
            if item.item_name.lower() not in MENU_PRICES:
                raise ValueError(f"Item not found on menu: {item.item_name}")
            items_data.append(
                {
                    "item_name": item.item_name,
                    "quantity": item.quantity,
                }
            )

        order = await self._repo.create(
            user_id=data.user_id,
            table_number=data.table_number,
            items_data=items_data,
            menu_prices=MENU_PRICES,
            notes=data.notes,
        )

        logger.info(
            "Order created: %s for user %s, total=%s VND",
            order.id,
            data.user_id,
            order.total_price,
        )
        return self._to_response(order)

    async def get_order(self, order_id: str) -> OrderResponse | None:
        """Get an order by ID."""
        order = await self._repo.get_by_id(order_id)
        if not order:
            return None
        return self._to_response(order)

    async def get_user_orders(self, user_id: str) -> list[OrderResponse]:
        """Get all orders for a user."""
        orders = await self._repo.get_by_user_id(user_id)
        return [self._to_response(order) for order in orders]

    async def update_status(self, order_id: str, status: str) -> OrderResponse | None:
        """Update the status of an order."""
        order = await self._repo.get_by_id(order_id)
        if not order:
            return None

        valid_transitions = {
            "pending": {"preparing", "cancelled"},
            "preparing": {"ready", "cancelled"},
            "ready": {"delivered"},
            "delivered": set(),
            "cancelled": set(),
        }

        allowed = valid_transitions.get(order.status, set())
        if status not in allowed:
            raise ValueError(
                f"Cannot transition from '{order.status}' to '{status}'. "
                f"Allowed transitions: {allowed or 'none (terminal state)'}"
            )

        updated = await self._repo.update_status(order_id, status)
        if not updated:
            return None

        logger.info("Order %s status updated to %s", order_id, status)
        return self._to_response(updated)

    @staticmethod
    def _to_response(order) -> OrderResponse:
        items = []
        for item in order.items:
            items.append(
                OrderItemResponse(
                    id=str(item.id),
                    item_name=item.item_name,
                    quantity=item.quantity,
                    unit_price=item.unit_price,
                    total_price=item.unit_price * item.quantity,
                )
            )

        return OrderResponse(
            id=str(order.id),
            user_id=order.user_id,
            table_number=order.table_number,
            status=order.status,
            total_price=order.total_price,
            notes=order.notes,
            items=items,
            created_at=order.created_at if hasattr(order, "created_at") else None,
        )
