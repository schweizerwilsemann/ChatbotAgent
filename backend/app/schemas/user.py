import uuid
from datetime import datetime

from app.core.vietnam_phone import (
    identify_major_mobile_carrier,
    normalize_vietnam_phone,
)
from app.models.user import UserRole
from pydantic import BaseModel, EmailStr, Field, field_validator


class UserCreate(BaseModel):
    phone: str = Field(..., min_length=7, max_length=20)
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr | None = None


class UserLogin(BaseModel):
    phone: str = Field(..., min_length=7, max_length=20)
    password: str = Field(..., min_length=1, max_length=128)

    @field_validator("phone", mode="before")
    @classmethod
    def normalize_phone(cls, value: object) -> object:
        if isinstance(value, str):
            return normalize_vietnam_phone(value)
        return value


class UserRegister(BaseModel):
    phone: str = Field(..., min_length=10, max_length=10)
    name: str = Field(..., min_length=1, max_length=100)
    password: str = Field(..., min_length=8, max_length=128)

    @field_validator("phone", mode="before")
    @classmethod
    def validate_phone(cls, value: object) -> object:
        if not isinstance(value, str):
            return value

        normalized = normalize_vietnam_phone(value)
        if identify_major_mobile_carrier(normalized) is None:
            raise ValueError(
                "Số điện thoại phải thuộc Viettel, VinaPhone hoặc MobiFone"
            )
        return normalized

    @field_validator("name", mode="before")
    @classmethod
    def trim_name(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip()
        return value


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(..., min_length=1, max_length=128)
    new_password: str = Field(..., min_length=8, max_length=128)


class UserResponse(BaseModel):
    id: uuid.UUID
    phone: str
    name: str
    email: str | None = None
    business_id: uuid.UUID | None = None
    default_venue_id: uuid.UUID | None = None
    role: UserRole
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class AuthResponse(BaseModel):
    user: UserResponse
    token: str
