import logging
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.auth import get_current_user, require_roles
from app.core.database import get_db
from app.models.partner import (
    PartnerMenuItem,
    PartnerOrder,
    PartnerOrderItem,
    PartnerOrderStatus,
    PartnerStore,
    PartnerStoreStatus,
)
from app.models.user import User, UserRole
from app.schemas.partner import (
    PartnerMenuItemCreate,
    PartnerMenuItemResponse,
    PartnerMenuItemUpdate,
    PartnerOrderCreate,
    PartnerOrderItemResponse,
    PartnerOrderResponse,
    PartnerOrderStatusUpdate,
    PartnerStoreResponse,
    PartnerStoreUpdate,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/partner", tags=["partner"])


# ── Helpers ────────────────────────────────────────────
async def _get_owned_store(
    user: User,
    session: AsyncSession,
    store_id: str | None = None,
) -> PartnerStore:
    """Get the partner store owned by the current user."""
    stmt = select(PartnerStore).where(
        PartnerStore.owner_user_id == str(user.id),
        PartnerStore.is_deleted == False,  # noqa: E712
    )
    if store_id:
        stmt = stmt.where(PartnerStore.id == store_id)
    result = await session.execute(stmt)
    store = result.scalar_one_or_none()
    if not store:
        raise HTTPException(
            status_code=404, detail="Store not found or not owned by you"
        )
    return store


def _order_to_response(order: PartnerOrder, store_name: str | None = None) -> PartnerOrderResponse:
    return PartnerOrderResponse(
        id=str(order.id),
        store_id=str(order.store_id) if order.store_id else None,
        store_name=store_name,
        customer_user_id=order.customer_user_id,
        customer_name=order.customer_name,
        customer_phone=order.customer_phone,
        venue_id=str(order.venue_id) if order.venue_id else None,
        delivery_location=order.delivery_location,
        status=order.status.value if isinstance(order.status, PartnerOrderStatus) else order.status,
        payment_status=order.payment_status,
        subtotal=order.subtotal,
        delivery_fee=order.delivery_fee,
        total_price=order.total_price,
        notes=order.notes,
        items=[
            PartnerOrderItemResponse(
                id=str(item.id),
                item_name=item.item_name,
                quantity=item.quantity,
                unit_price=item.unit_price,
            )
            for item in (order.items or [])
        ],
        created_at=order.created_at,
    )


# ══════════════════════════════════════════════════════
# PARTNER ENDPOINTS (manage own store)
# ══════════════════════════════════════════════════════


@router.get("/me/store", response_model=PartnerStoreResponse)
async def get_my_store(
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Get the partner's own store."""
    store = await _get_owned_store(user, session)
    return PartnerStoreResponse(
        id=str(store.id),
        owner_user_id=store.owner_user_id,
        venue_id=str(store.venue_id) if store.venue_id else None,
        name=store.name,
        description=store.description,
        category=store.category,
        logo_url=store.logo_url,
        phone=store.phone,
        address=store.address,
        status=store.status.value if isinstance(store.status, PartnerStoreStatus) else store.status,
        is_open=store.is_open,
        rating=store.rating,
        total_orders=store.total_orders,
        delivery_fee=store.delivery_fee,
        estimated_delivery_minutes=store.estimated_delivery_minutes,
        created_at=store.created_at,
    )


@router.patch("/me/store", response_model=PartnerStoreResponse)
async def update_my_store(
    data: PartnerStoreUpdate,
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Update the partner's own store info."""
    store = await _get_owned_store(user, session)
    update_data = data.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    for key, value in update_data.items():
        setattr(store, key, value)
    await session.commit()
    await session.refresh(store)
    return PartnerStoreResponse(
        id=str(store.id),
        owner_user_id=store.owner_user_id,
        venue_id=str(store.venue_id) if store.venue_id else None,
        name=store.name,
        description=store.description,
        category=store.category,
        logo_url=store.logo_url,
        phone=store.phone,
        address=store.address,
        status=store.status.value if isinstance(store.status, PartnerStoreStatus) else store.status,
        is_open=store.is_open,
        rating=store.rating,
        total_orders=store.total_orders,
        delivery_fee=store.delivery_fee,
        estimated_delivery_minutes=store.estimated_delivery_minutes,
        created_at=store.created_at,
    )


# ── Menu Items CRUD ────────────────────────────────────


@router.get("/me/menu", response_model=list[PartnerMenuItemResponse])
async def get_my_menu(
    include_unavailable: bool = Query(False),
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Get all menu items for the partner's store."""
    store = await _get_owned_store(user, session)
    stmt = (
        select(PartnerMenuItem)
        .where(
            PartnerMenuItem.store_id == store.id,
            PartnerMenuItem.is_deleted == False,  # noqa: E712
        )
        .order_by(PartnerMenuItem.category, PartnerMenuItem.name)
    )
    if not include_unavailable:
        stmt = stmt.where(PartnerMenuItem.is_available == True)  # noqa: E712
    result = await session.execute(stmt)
    items = result.scalars().all()
    return [
        PartnerMenuItemResponse(
            id=str(item.id),
            store_id=str(item.store_id),
            name=item.name,
            description=item.description,
            price=item.price,
            category=item.category,
            image_url=item.image_url,
            is_available=item.is_available,
            sales_count=item.sales_count,
            created_at=item.created_at,
        )
        for item in items
    ]


@router.post("/me/menu", response_model=PartnerMenuItemResponse, status_code=201)
async def create_menu_item(
    data: PartnerMenuItemCreate,
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Add a new menu item to the partner's store."""
    store = await _get_owned_store(user, session)
    item = PartnerMenuItem(
        store_id=store.id,
        name=data.name,
        description=data.description,
        price=data.price,
        category=data.category,
        image_url=data.image_url,
        is_available=data.is_available,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return PartnerMenuItemResponse(
        id=str(item.id),
        store_id=str(item.store_id),
        name=item.name,
        description=item.description,
        price=item.price,
        category=item.category,
        image_url=item.image_url,
        is_available=item.is_available,
        sales_count=item.sales_count,
        created_at=item.created_at,
    )


@router.patch("/me/menu/{item_id}", response_model=PartnerMenuItemResponse)
async def update_menu_item(
    item_id: str,
    data: PartnerMenuItemUpdate,
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Update a menu item (price, availability, etc.)."""
    store = await _get_owned_store(user, session)
    stmt = select(PartnerMenuItem).where(
        PartnerMenuItem.id == item_id,
        PartnerMenuItem.store_id == store.id,
        PartnerMenuItem.is_deleted == False,  # noqa: E712
    )
    result = await session.execute(stmt)
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    update_data = data.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    for key, value in update_data.items():
        setattr(item, key, value)
    await session.commit()
    await session.refresh(item)
    return PartnerMenuItemResponse(
        id=str(item.id),
        store_id=str(item.store_id),
        name=item.name,
        description=item.description,
        price=item.price,
        category=item.category,
        image_url=item.image_url,
        is_available=item.is_available,
        sales_count=item.sales_count,
        created_at=item.created_at,
    )


@router.delete("/me/menu/{item_id}", status_code=204)
async def delete_menu_item(
    item_id: str,
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Soft-delete a menu item."""
    store = await _get_owned_store(user, session)
    stmt = select(PartnerMenuItem).where(
        PartnerMenuItem.id == item_id,
        PartnerMenuItem.store_id == store.id,
        PartnerMenuItem.is_deleted == False,  # noqa: E712
    )
    result = await session.execute(stmt)
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    item.is_deleted = True
    from datetime import datetime, timezone
    item.deleted_at = datetime.now(timezone.utc)
    await session.commit()


# ── Orders ─────────────────────────────────────────────


@router.get("/me/orders", response_model=list[PartnerOrderResponse])
async def get_my_orders(
    status: str | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Get orders for the partner's store."""
    store = await _get_owned_store(user, session)
    stmt = (
        select(PartnerOrder)
        .where(PartnerOrder.store_id == store.id)
        .order_by(PartnerOrder.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    if status:
        stmt = stmt.where(PartnerOrder.status == status)
    result = await session.execute(stmt)
    orders = result.scalars().all()
    # Eagerly load items
    for order in orders:
        await session.refresh(order, attribute_names=["items"])
    return [_order_to_response(o, store_name=store.name) for o in orders]


@router.patch(
    "/me/orders/{order_id}/status", response_model=PartnerOrderResponse
)
async def update_order_status(
    order_id: str,
    data: PartnerOrderStatusUpdate,
    user: User = Depends(require_roles("PARTNER")),
    session: AsyncSession = Depends(get_db),
):
    """Update order status (accept, preparing, ready, delivered, cancelled)."""
    store = await _get_owned_store(user, session)
    stmt = select(PartnerOrder).where(
        PartnerOrder.id == order_id,
        PartnerOrder.store_id == store.id,
    )
    result = await session.execute(stmt)
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    current = order.status.value if isinstance(order.status, PartnerOrderStatus) else order.status
    new_status = data.status

    # Validate transitions
    valid_transitions = {
        "pending": {"accepted", "cancelled"},
        "accepted": {"preparing", "cancelled"},
        "preparing": {"ready", "cancelled"},
        "ready": {"delivering"},
        "delivering": {"delivered"},
    }
    allowed = valid_transitions.get(current, set())
    if new_status not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot transition from '{current}' to '{new_status}'",
        )

    order.status = PartnerOrderStatus(new_status)
    if new_status == "delivered":
        store.total_orders = (store.total_orders or 0) + 1
    await session.flush()
    # Eagerly load items before commit to avoid lazy-load issues
    await session.refresh(order, attribute_names=["items"])
    resp = _order_to_response(order, store_name=store.name)
    await session.commit()
    return resp


# ══════════════════════════════════════════════════════
# PUBLIC ENDPOINTS (for customers / mini app)
# ══════════════════════════════════════════════════════


@router.get("/stores", response_model=list[PartnerStoreResponse])
async def list_partner_stores(
    venue_id: str | None = Query(None),
    category: str | None = Query(None),
    session: AsyncSession = Depends(get_db),
):
    """List active partner stores (public, for mini app)."""
    stmt = select(PartnerStore).where(
        PartnerStore.status == PartnerStoreStatus.active,
        PartnerStore.is_deleted == False,  # noqa: E712
    )
    if venue_id:
        stmt = stmt.where(PartnerStore.venue_id == venue_id)
    if category:
        stmt = stmt.where(PartnerStore.category == category)
    stmt = stmt.order_by(PartnerStore.rating.desc())
    result = await session.execute(stmt)
    stores = result.scalars().all()
    return [
        PartnerStoreResponse(
            id=str(s.id),
            owner_user_id=s.owner_user_id,
            venue_id=str(s.venue_id) if s.venue_id else None,
            name=s.name,
            description=s.description,
            category=s.category,
            logo_url=s.logo_url,
            phone=s.phone,
            address=s.address,
            status=s.status.value if isinstance(s.status, PartnerStoreStatus) else s.status,
            is_open=s.is_open,
            rating=s.rating,
            total_orders=s.total_orders,
            delivery_fee=s.delivery_fee,
            estimated_delivery_minutes=s.estimated_delivery_minutes,
            created_at=s.created_at,
        )
        for s in stores
    ]


@router.get("/stores/{store_id}/menu", response_model=list[PartnerMenuItemResponse])
async def get_store_menu(
    store_id: str,
    session: AsyncSession = Depends(get_db),
):
    """Get available menu items for a store (public, for mini app)."""
    stmt = select(PartnerMenuItem).where(
        PartnerMenuItem.store_id == store_id,
        PartnerMenuItem.is_available == True,  # noqa: E712
        PartnerMenuItem.is_deleted == False,  # noqa: E712
    )
    result = await session.execute(stmt)
    items = result.scalars().all()
    return [
        PartnerMenuItemResponse(
            id=str(item.id),
            store_id=str(item.store_id),
            name=item.name,
            description=item.description,
            price=item.price,
            category=item.category,
            image_url=item.image_url,
            is_available=item.is_available,
            sales_count=item.sales_count,
            created_at=item.created_at,
        )
        for item in items
    ]


@router.post("/orders", response_model=PartnerOrderResponse, status_code=201)
async def create_partner_order(
    data: PartnerOrderCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    """Create an order from a partner store (customer-facing)."""
    # Verify store exists and is open
    store_stmt = select(PartnerStore).where(
        PartnerStore.id == data.store_id,
        PartnerStore.status == PartnerStoreStatus.active,
        PartnerStore.is_open == True,  # noqa: E712
    )
    store_result = await session.execute(store_stmt)
    store = store_result.scalar_one_or_none()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found or closed")

    # Build order
    subtotal = Decimal("0")
    order_items = []
    for item_data in data.items:
        line_total = item_data.unit_price * item_data.quantity
        subtotal += line_total
        order_items.append(
            PartnerOrderItem(
                item_name=item_data.item_name,
                quantity=item_data.quantity,
                unit_price=item_data.unit_price,
            )
        )

    total = subtotal + store.delivery_fee

    order = PartnerOrder(
        store_id=store.id,
        customer_user_id=str(user.id),
        customer_name=user.name,
        customer_phone=user.phone,
        venue_id=store.venue_id,
        delivery_location=data.delivery_location,
        status=PartnerOrderStatus.pending,
        payment_status="unpaid",
        subtotal=subtotal,
        delivery_fee=store.delivery_fee,
        total_price=total,
        notes=data.notes,
        items=order_items,
    )
    session.add(order)
    await session.flush()
    # Build response before commit to avoid lazy-load issues
    resp = _order_to_response(order, store_name=store.name)
    await session.commit()
    return resp
