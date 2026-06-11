from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator


# ── Store ──────────────────────────────────────────────
class PartnerStoreResponse(BaseModel):
    id: str
    owner_user_id: str
    venue_id: str | None = None
    name: str
    description: str = ""
    category: str = "food"
    logo_url: str | None = None
    phone: str | None = None
    address: str | None = None
    status: str = "active"
    is_open: bool = True
    rating: Decimal = Decimal("5.00")
    total_orders: int = 0
    delivery_fee: Decimal = Decimal("15000")
    estimated_delivery_minutes: int = 20
    created_at: datetime | None = None

    class Config:
        from_attributes = True


class PartnerStoreUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    category: str | None = None
    logo_url: str | None = None
    phone: str | None = None
    address: str | None = None
    is_open: bool | None = None
    delivery_fee: Decimal | None = Field(None, ge=0)
    estimated_delivery_minutes: int | None = Field(None, ge=1, le=120)


# ── Menu Item ──────────────────────────────────────────
class PartnerMenuItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: str = ""
    price: Decimal = Field(..., gt=0)
    category: str = Field("food", max_length=64)
    image_url: str | None = None
    is_available: bool = True


class PartnerMenuItemUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    price: Decimal | None = Field(None, gt=0)
    category: str | None = None
    image_url: str | None = None
    is_available: bool | None = None


class PartnerMenuItemResponse(BaseModel):
    id: str
    store_id: str
    name: str
    description: str = ""
    price: Decimal
    category: str = "food"
    image_url: str | None = None
    is_available: bool = True
    sales_count: int = 0
    created_at: datetime | None = None

    class Config:
        from_attributes = True


# ── Order ──────────────────────────────────────────────
class PartnerOrderItemCreate(BaseModel):
    item_id: str = Field(..., description="PartnerMenuItem ID")
    item_name: str = Field(..., min_length=1, max_length=255)
    quantity: int = Field(..., ge=1, le=99)
    unit_price: Decimal = Field(..., gt=0)


class PartnerOrderCreate(BaseModel):
    store_id: str = Field(..., description="PartnerStore ID")
    items: list[PartnerOrderItemCreate] = Field(..., min_length=1)
    delivery_location: str | None = Field(
        None, max_length=255, description="e.g. Bàn B03, Sân P02"
    )
    notes: str | None = Field("", max_length=500)


class PartnerOrderItemResponse(BaseModel):
    id: str
    item_name: str
    quantity: int
    unit_price: Decimal

    class Config:
        from_attributes = True


class PartnerOrderResponse(BaseModel):
    id: str
    store_id: str | None = None
    store_name: str | None = None
    customer_user_id: str
    customer_name: str | None = None
    customer_phone: str | None = None
    venue_id: str | None = None
    delivery_location: str | None = None
    status: str
    payment_status: str = "unpaid"
    subtotal: Decimal
    delivery_fee: Decimal
    total_price: Decimal
    notes: str | None = None
    items: list[PartnerOrderItemResponse] = []
    created_at: datetime | None = None

    class Config:
        from_attributes = True


class PartnerOrderStatusUpdate(BaseModel):
    status: str = Field(..., description="New order status")

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        allowed = {
            "accepted",
            "preparing",
            "ready",
            "delivering",
            "delivered",
            "cancelled",
        }
        if v.lower() not in allowed:
            raise ValueError(f"status must be one of {allowed}")
        return v.lower()
