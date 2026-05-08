import uuid
from datetime import datetime

from app.models.user import UserRole
from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    phone: str = Field(..., min_length=7, max_length=20)
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr | None = None


class UserResponse(BaseModel):
    id: uuid.UUID
    phone: str
    name: str
    email: str | None = None
    role: UserRole
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
