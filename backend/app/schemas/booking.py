from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class BookingCreate(BaseModel):
    court_type: str = Field(
        ..., description="Type of court: billiards, pickleball, badminton"
    )
    court_number: int = Field(..., ge=1, description="Court number")
    start_time: datetime = Field(..., description="Booking start time (ISO 8601)")
    end_time: datetime = Field(..., description="Booking end time (ISO 8601)")
    notes: str = Field("", max_length=500, description="Additional notes")

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
        if start and v <= start:
            raise ValueError("end_time must be after start_time")
        return v


class BookingResponse(BaseModel):
    id: str
    user_id: str
    court_type: str
    court_number: int
    start_time: datetime
    end_time: datetime
    status: str
    notes: str | None = None
    created_at: datetime | None = None

    class Config:
        from_attributes = True


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
