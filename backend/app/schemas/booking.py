from datetime import date as DateType
from datetime import datetime, time
from decimal import Decimal
from zoneinfo import ZoneInfo

from pydantic import BaseModel, Field, field_validator

from app.core.config import settings
from app.schemas.order import OrderResponse


class BookingCreate(BaseModel):
    venue_id: str | None = Field(None, description="Venue/branch identifier")
    resource_id: str | None = Field(None, description="Selected table/court resource")
    resource_label: str | None = Field(
        None,
        max_length=255,
        description="Human-readable table/court label",
    )
    court_type: str = Field(
        ..., description="Type of court: billiards, pickleball, badminton"
    )
    court_number: int = Field(..., ge=1, description="Court number")
    date: DateType | None = Field(None, description="Booking date")
    start_time: datetime | str = Field(..., description="Booking start time")
    end_time: datetime | str = Field(..., description="Booking end time")
    notes: str | None = Field("", max_length=500, description="Additional notes")
    user_id: str | None = None

    @field_validator("court_type")
    @classmethod
    def validate_court_type(cls, v: str) -> str:
        allowed = {"billiards", "pickleball", "badminton"}
        if v.lower() not in allowed:
            raise ValueError(f"court_type must be one of {allowed}")
        return v.lower()

    @field_validator("end_time")
    @classmethod
    def validate_times(cls, v: datetime, info) -> datetime:
        start = info.data.get("start_time")
        if isinstance(start, datetime) and isinstance(v, datetime) and v <= start:
            raise ValueError("end_time must be after start_time")
        return v

    def to_start_datetime(self) -> datetime:
        return _combine_date_time(self.date, self.start_time)

    def to_end_datetime(self) -> datetime:
        return _combine_date_time(self.date, self.end_time)


class BookingResponse(BaseModel):
    id: str
    user_id: str
    venue_id: str | None = None
    resource_id: str | None = None
    resource_label: str | None = None
    court_type: str
    court_number: int
    date: DateType
    start_time: str
    end_time: str
    status: str
    payment_status: str = "unpaid"
    total_price: float | None = None
    notes: str | None = None
    checked_in_at: datetime | None = None
    checked_in_by: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    class Config:
        from_attributes = True


class BookingBillResponse(BaseModel):
    booking: BookingResponse
    orders: list[OrderResponse]
    order_total: Decimal
    booking_total: Decimal | None = None
    grand_total: Decimal
    paid_total: Decimal = Decimal("0")
    unpaid_total: Decimal = Decimal("0")


class BookingCheckInConfirm(BaseModel):
    token: str = Field(..., min_length=8, max_length=256)


class BookingCancelResponse(BaseModel):
    id: str
    status: str
    message: str


class AvailabilityQuery(BaseModel):
    court_type: str = Field(..., description="Type of court")
    court_number: int = Field(..., ge=1)
    start_time: datetime
    end_time: datetime

    @field_validator("court_type")
    @classmethod
    def validate_court_type(cls, v: str) -> str:
        allowed = {"billiards", "pickleball", "badminton"}
        if v.lower() not in allowed:
            raise ValueError(f"court_type must be one of {allowed}")
        return v.lower()


class TimeSlotResponse(BaseModel):
    start_time: str
    end_time: str
    is_available: bool


class AvailabilityResponse(BaseModel):
    court_type: str
    date: DateType
    slots: list[TimeSlotResponse]
    available_courts: list[int]


def _combine_date_time(value_date: DateType | None, value: datetime | str) -> datetime:
    tz = ZoneInfo(settings.DEFAULT_TIMEZONE)
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=tz)
        return value
    if value_date is None:
        dt = datetime.fromisoformat(value)
        return dt.replace(tzinfo=tz) if dt.tzinfo is None else dt
    parsed_time = time.fromisoformat(value)
    return datetime.combine(value_date, parsed_time, tzinfo=tz)
