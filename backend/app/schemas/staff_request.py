from datetime import datetime

from pydantic import BaseModel, Field


class StaffRequestCreate(BaseModel):
    venue_id: str | None = Field(None, description="Venue/branch identifier")
    resource_id: str | None = Field(None, description="Table/court resource ID")
    resource_label: str | None = Field(
        None,
        max_length=255,
        description="Human-readable table/court label",
    )
    request_type: str = Field(
        ...,
        description="Type of request: order, payment, help, maintenance, other",
    )
    description: str | None = Field(
        None, max_length=1000, description="Additional description"
    )
    table_number: int | None = Field(None, ge=0, description="Table/court number")


class StaffRequestResponse(BaseModel):
    id: str
    user_id: str
    user_name: str | None = None
    venue_id: str | None = None
    resource_id: str | None = None
    resource_label: str | None = None
    request_type: str
    description: str | None = None
    table_number: int | None = None
    status: str
    accepted_by: str | None = None
    accepted_by_name: str | None = None
    created_at: datetime | None = None
    accepted_at: datetime | None = None
    completed_at: datetime | None = None

    class Config:
        from_attributes = True


class StaffRequestActionResponse(BaseModel):
    id: str
    status: str
    message: str
