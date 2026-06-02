import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user, require_roles
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.repositories.menu_repository import MenuRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.order_repository import OrderRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.order import OrderCreate, OrderResponse, OrderStatusUpdate
from app.services.notification_service import NotificationService
from app.services.order_service import OrderService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/order", tags=["order"])


async def _get_order_service(
    session: AsyncSession = Depends(get_db),
) -> OrderService:
    repo = OrderRepository(session)
    menu_repo = MenuRepository(session)
    venue_repo = VenueRepository(session)
    notification_service = NotificationService(
        NotificationRepository(session),
        venue_repo,
    )
    return OrderService(repo, menu_repo, notification_service, venue_repo)


@router.post("", response_model=OrderResponse, status_code=201)
async def create_order(
    data: OrderCreate,
    _: None = Depends(rate_limit(limit=10, window_seconds=60, scope="order")),
    user: User = Depends(get_current_user),
    service: OrderService = Depends(_get_order_service),
) -> OrderResponse:
    """Create a new menu item order."""
    try:
        data.user_id = str(user.id)
        order = await service.create_order(data, user=user)
        return order
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error creating order")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("", response_model=list[OrderResponse])
async def get_orders(
    user_id: str | None = Query(None, description="User ID"),
    user: User = Depends(get_current_user),
    service: OrderService = Depends(_get_order_service),
) -> list[OrderResponse]:
    """Get all menu item orders for a user."""
    try:
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        target_user_id = (
            user_id if role_value in {"STAFF", "ADMIN"} and user_id else str(user.id)
        )
        return await service.get_user_orders(target_user_id)
    except Exception as exc:
        logger.exception("Error fetching user orders")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: str,
    user: User = Depends(get_current_user),
    service: OrderService = Depends(_get_order_service),
) -> OrderResponse:
    """Get an order by ID."""
    order = await service.get_order(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_value not in {"STAFF", "ADMIN"} and order.user_id != str(user.id):
        raise HTTPException(
            status_code=403, detail="Cannot access another user's order"
        )
    return order


@router.put("/{order_id}/status", response_model=OrderResponse)
async def update_order_status(
    order_id: str,
    data: OrderStatusUpdate,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
    service: OrderService = Depends(_get_order_service),
) -> OrderResponse:
    """Update the status of an order."""
    try:
        existing = await service.get_order(order_id)
        if not existing:
            raise HTTPException(status_code=404, detail="Order not found")
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        if role_value == "STAFF":
            venue_repo = VenueRepository(session)
            access = await venue_repo.get_staff_access(str(user.id))
            if access.has_assignments:
                resource_ids = await venue_repo.expand_accessible_resource_ids(access)
                can_update = False
                if existing.resource_id and existing.resource_id in {
                    str(item) for item in resource_ids
                }:
                    can_update = True
                if existing.venue_id and existing.venue_id in {
                    str(item) for item in access.venue_scope_ids
                }:
                    can_update = True
                if not can_update:
                    raise HTTPException(
                        status_code=403,
                        detail="Order is outside your assigned tables/courts",
                    )
        order = await service.update_status(order_id, data.status)
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        return order
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error updating order status")
        raise HTTPException(status_code=500, detail="Internal server error") from exc
