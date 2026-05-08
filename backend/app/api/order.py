import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.repositories.order_repository import OrderRepository
from app.schemas.order import OrderCreate, OrderResponse, OrderStatusUpdate
from app.services.order_service import OrderService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/order", tags=["order"])


async def _get_order_service(
    session: AsyncSession = Depends(get_db),
) -> OrderService:
    repo = OrderRepository(session)
    return OrderService(repo)


@router.post("/", response_model=OrderResponse, status_code=201)
async def create_order(
    data: OrderCreate,
    service: OrderService = Depends(_get_order_service),
) -> OrderResponse:
    """Create a new food/drink order."""
    try:
        order = await service.create_order(data)
        return order
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error creating order")
        raise HTTPException(status_code=500, detail="Internal server error") from exc


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: str,
    service: OrderService = Depends(_get_order_service),
) -> OrderResponse:
    """Get an order by ID."""
    order = await service.get_order(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.put("/{order_id}/status", response_model=OrderResponse)
async def update_order_status(
    order_id: str,
    data: OrderStatusUpdate,
    service: OrderService = Depends(_get_order_service),
) -> OrderResponse:
    """Update the status of an order."""
    try:
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
