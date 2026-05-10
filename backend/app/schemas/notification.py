from datetime import datetime

from pydantic import BaseModel, Field


class StaffNotifyRequest(BaseModel):
    message: str = Field(
        ..., min_length=1, max_length=1000, description="Notification message"
    )
    table_number: int = Field(0, ge=0, description="Table number (0 if not applicable)")


class NotificationResponse(BaseModel):
    id: str
    event_type: str
    title: str
    message: str
    target_roles: list[str]
    source: str
    payload: dict
    created_at: datetime | None = None
    read_at: datetime | None = None


class StaffNotifyResponse(BaseModel):
    notification_id: str
    message: str
    table_number: int
    status: str
    timestamp: str
