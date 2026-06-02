import logging

from app.repositories.menu_repository import MenuRepository
from app.repositories.order_repository import OrderRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.order import OrderCreate, OrderItemResponse, OrderResponse
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)


class OrderService:
    def __init__(
        self,
        repo: OrderRepository,
        menu_repo: MenuRepository,
        notification_service: NotificationService | None = None,
        venue_repo: VenueRepository | None = None,
    ) -> None:
        self._repo = repo
        self._menu_repo = menu_repo
        self._notification_service = notification_service
        self._venue_repo = venue_repo

    async def create_order(self, data: OrderCreate, user=None) -> OrderResponse:
        """Create a new order, calculating total price from the menu."""
        if not data.items:
            raise ValueError("Order must contain at least one item")

        venue_id = data.venue_id
        resource_id = data.resource_id
        resource_label = data.resource_label
        table_number = data.table_number
        if self._venue_repo:
            resolved_venue_id = await self._venue_repo.resolve_user_venue_id(
                user,
                explicit_venue_id=venue_id,
            )
            venue_id = str(resolved_venue_id) if resolved_venue_id else venue_id

            resource = None
            if resource_id:
                resource = await self._venue_repo.get_resource_by_id(resource_id)
                if not resource:
                    raise ValueError("Selected table/court was not found")
            elif table_number > 0:
                resource = await self._venue_repo.resolve_legacy_resource(
                    venue_id=venue_id,
                    table_number=table_number,
                )

            if resource:
                venue_id = str(resource.venue_id)
                resource_id = str(resource.id)
                resource_label = data.resource_label or resource.name
                table_number = resource.number

        item_names = [item.item_name for item in data.items]
        menu_items = await self._menu_repo.find_available_by_names(
            item_names,
            venue_id=venue_id,
        )

        items_data = []
        quantities_by_name: dict[str, int] = {}
        menu_prices = {}
        for item in data.items:
            menu_item = menu_items.get(item.item_name.lower())
            if menu_item is None:
                raise ValueError(f"Item not found on menu: {item.item_name}")
            menu_prices[item.item_name.lower()] = menu_item.price
            quantities_by_name[item.item_name] = (
                quantities_by_name.get(item.item_name, 0) + item.quantity
            )
            items_data.append(
                {
                    "item_name": item.item_name,
                    "quantity": item.quantity,
                }
            )

        order = await self._repo.create(
            user_id=data.user_id,
            venue_id=venue_id,
            resource_id=resource_id,
            resource_label=resource_label,
            table_number=table_number,
            items_data=items_data,
            menu_prices=menu_prices,
            notes=data.notes,
        )
        await self._menu_repo.increment_sales(quantities_by_name, venue_id=venue_id)

        logger.info(
            "Order created: %s for user %s, total=%s VND",
            order.id,
            data.user_id,
            order.total_price,
        )
        response = self._to_response(order)
        if self._notification_service:
            await self._notification_service.notify_operations(
                event_type="order.created",
                title="Đơn hàng mới",
                message=(
                    f"Khách vừa đặt {len(response.items)} món"
                    f"{f' tại {response.resource_label}' if response.resource_label else ''}, "
                    f"tổng {response.total_price:,.0f} VND"
                ),
                source="order",
                payload=response.model_dump(mode="json"),
            )
        return response

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
            venue_id=str(order.venue_id) if getattr(order, "venue_id", None) else None,
            resource_id=str(order.resource_id)
            if getattr(order, "resource_id", None)
            else None,
            resource_label=getattr(order, "resource_label", None),
            table_number=order.table_number,
            status=order.status,
            total_price=order.total_price,
            notes=order.notes,
            items=items,
            created_at=order.created_at if hasattr(order, "created_at") else None,
        )
