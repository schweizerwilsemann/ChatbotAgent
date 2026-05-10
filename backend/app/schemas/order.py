from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator


class OrderItemCreate(BaseModel):
    item_name: str = Field(..., min_length=1, max_length=255)
    quantity: int = Field(..., ge=1, le=99)


class OrderCreate(BaseModel):
    user_id: str = Field("current_user", min_length=1, max_length=128)
    table_number: int = Field(0, ge=0)
    items: list[OrderItemCreate] = Field(..., min_length=1)
    notes: str | None = Field("", max_length=500)


class OrderItemResponse(BaseModel):
    id: str
    item_name: str
    quantity: int
    unit_price: Decimal
    total_price: Decimal

    class Config:
        from_attributes = True


class OrderResponse(BaseModel):
    id: str
    user_id: str
    table_number: int
    status: str
    total_price: Decimal
    notes: str | None = None
    items: list[OrderItemResponse] = []
    created_at: datetime | None = None

    class Config:
        from_attributes = True


class OrderStatusUpdate(BaseModel):
    status: str = Field(..., description="New order status")

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        allowed = {"pending", "preparing", "ready", "delivered", "cancelled"}
        if v.lower() not in allowed:
            raise ValueError(f"status must be one of {allowed}")
        return v.lower()
