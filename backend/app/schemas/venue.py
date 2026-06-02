from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator


class BusinessResponse(BaseModel):
    id: str
    name: str
    slug: str
    is_active: bool


class VenueResponse(BaseModel):
    id: str
    business_id: str
    name: str
    address: str | None = None
    timezone: str
    is_active: bool


class VenueAreaResponse(BaseModel):
    id: str
    venue_id: str
    name: str
    sort_order: int


class ServiceResourceResponse(BaseModel):
    id: str
    venue_id: str
    area_id: str | None = None
    area_name: str | None = None
    code: str
    name: str
    label: str
    resource_type: str
    sport_type: str | None = None
    number: int
    capacity: int | None = None
    status: str
    metadata: dict = Field(default_factory=dict)
    hourly_rate: Decimal | None = None


class ServiceResourceCreate(BaseModel):
    venue_id: str
    area_id: str | None = None
    code: str = Field(..., min_length=1, max_length=40)
    name: str = Field(..., min_length=1, max_length=255)
    resource_type: str
    sport_type: str | None = Field(None, max_length=40)
    number: int = Field(..., ge=1)
    capacity: int | None = Field(None, ge=1)
    status: str = "active"
    metadata: dict = Field(default_factory=dict)
    hourly_rate: Decimal | None = Field(None, ge=0)

    @field_validator("resource_type")
    @classmethod
    def validate_resource_type(cls, value: str) -> str:
        allowed = {
            "billiards_table",
            "pickleball_court",
            "badminton_court",
            "dining_table",
            "other",
        }
        normalized = value.lower()
        if normalized not in allowed:
            raise ValueError(f"resource_type must be one of {allowed}")
        return normalized

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        allowed = {"active", "maintenance", "inactive"}
        normalized = value.lower()
        if normalized not in allowed:
            raise ValueError(f"status must be one of {allowed}")
        return normalized


class ServiceResourceUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=255)
    area_id: str | None = None
    status: str | None = None
    hourly_rate: Decimal | None = None

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str | None) -> str | None:
        if value is None:
            return value
        allowed = {"active", "maintenance", "inactive"}
        normalized = value.lower()
        if normalized not in allowed:
            raise ValueError(f"status must be one of {allowed}")
        return normalized


class StaffAssignmentResponse(BaseModel):
    id: str
    staff_id: str
    venue_id: str
    area_id: str | None = None
    resource_id: str | None = None
    scope: str
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_active: bool


class StaffAssignmentCreate(BaseModel):
    staff_id: str = Field(..., min_length=1, max_length=128)
    venue_id: str
    area_id: str | None = None
    resource_id: str | None = None
    scope: str = "venue"
    starts_at: datetime | None = None
    ends_at: datetime | None = None

    @field_validator("scope")
    @classmethod
    def validate_scope(cls, value: str) -> str:
        allowed = {"venue", "area", "resource"}
        normalized = value.lower()
        if normalized not in allowed:
            raise ValueError(f"scope must be one of {allowed}")
        return normalized
