from datetime import datetime

from pydantic import BaseModel, Field


class StaffChatMessage(BaseModel):
    id: str
    room_id: str
    sender_id: str
    sender_name: str
    sender_role: str  # "customer" | "staff"
    content: str
    timestamp: datetime


class StaffChatRoomInfo(BaseModel):
    request_id: str
    user_id: str
    user_name: str | None = None
    staff_id: str
    staff_name: str | None = None
    venue_id: str | None = None
    resource_label: str | None = None
    status: str = "active"  # "active" | "closed"


class StaffChatSendMessage(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)
