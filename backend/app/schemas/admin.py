from datetime import date as DateType
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator

# --- Dashboard ---


class DashboardResponse(BaseModel):
    total_revenue: Decimal
    bookings_today: int
    orders_today: int
    active_courts: int
    total_courts: int


# --- Bookings ---


class AdminBookingResponse(BaseModel):
    id: str
    user_id: str
    user_name: str | None = None
    court_type: str
    court_number: int
    date: DateType
    start_time: str
    end_time: str
    status: str
    total_price: float | None = None
    notes: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    class Config:
        from_attributes = True


class BookingStatusUpdate(BaseModel):
    status: str = Field(
        ..., description="New booking status: confirmed, cancelled, completed"
    )

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        allowed = {"confirmed", "cancelled", "completed"}
        if v.lower() not in allowed:
            raise ValueError(f"status must be one of {allowed}")
        return v.lower()


# --- Menu ---


class MenuItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    category_key: str = Field(..., min_length=1, max_length=64)
    category_name: str = Field(..., min_length=1, max_length=100)
    description: str = Field("", max_length=2000)
    unit: str = Field("", max_length=64)
    price: Decimal = Field(..., gt=0)
    image_url: str | None = None
    tags: str = Field("", max_length=500)


class MenuItemUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=255)
    category_key: str | None = Field(None, min_length=1, max_length=64)
    category_name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = Field(None, max_length=2000)
    unit: str | None = Field(None, max_length=64)
    price: Decimal | None = Field(None, gt=0)
    image_url: str | None = None
    tags: str | None = Field(None, max_length=500)


class MenuItemAvailabilityUpdate(BaseModel):
    is_available: bool


class MenuItemResponse(BaseModel):
    id: str | None = None
    name: str
    description: str
    price: Decimal
    image_url: str | None = None
    category: str
    category_key: str | None = None
    unit: str | None = None
    tags: str | None = None
    sales_count: int = 0
    is_available: bool = True
    created_at: datetime | None = None
    updated_at: datetime | None = None


# --- Analytics ---


class DayRevenue(BaseModel):
    date: DateType
    revenue: Decimal


class CourtBookingCount(BaseModel):
    court_type: str
    court_number: int
    count: int


class HourOrderCount(BaseModel):
    hour: int
    count: int


class DayOrderCount(BaseModel):
    date: DateType
    count: int


class AnalyticsResponse(BaseModel):
    revenue_by_day: list[DayRevenue]
    bookings_by_court: list[CourtBookingCount]
    orders_by_hour: list[HourOrderCount]
    order_count_by_day: list[DayOrderCount]
