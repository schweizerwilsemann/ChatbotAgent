from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError

from app.api.auth import register
from app.core.security import verify_password
from app.core.vietnam_phone import (
    VietnamMobileCarrier,
    identify_major_mobile_carrier,
    normalize_vietnam_phone,
)
from app.models.user import UserRole
from app.schemas.user import UserLogin, UserRegister


@pytest.mark.parametrize(
    ("phone", "normalized"),
    [
        ("090 123 4567", "0901234567"),
        ("+84 90 123 4567", "0901234567"),
        ("84901234567", "0901234567"),
    ],
)
def test_normalize_vietnam_phone(phone, normalized):
    assert normalize_vietnam_phone(phone) == normalized


@pytest.mark.parametrize(
    ("phone", "carrier"),
    [
        *[
            (f"{prefix}1234567", VietnamMobileCarrier.VIETTEL)
            for prefix in (
                "032",
                "033",
                "034",
                "035",
                "036",
                "037",
                "038",
                "039",
                "086",
                "096",
                "097",
                "098",
            )
        ],
        *[
            (f"{prefix}1234567", VietnamMobileCarrier.VINAPHONE)
            for prefix in ("081", "082", "083", "084", "085", "088", "091", "094")
        ],
        *[
            (f"{prefix}1234567", VietnamMobileCarrier.MOBIFONE)
            for prefix in ("070", "076", "077", "078", "079", "089", "090", "093")
        ],
    ],
)
def test_identify_major_mobile_carrier(phone, carrier):
    assert identify_major_mobile_carrier(phone) == carrier


@pytest.mark.parametrize("phone", ["0921234567", "0591234567", "0281234567"])
def test_register_rejects_unsupported_prefix(phone):
    with pytest.raises(ValidationError):
        UserRegister(phone=phone, name="Khach hang", password="password123")


def test_login_normalizes_international_phone_format():
    data = UserLogin(phone="+84 90 123 4567", password="password123")
    assert data.phone == "0901234567"


@pytest.mark.asyncio
async def test_register_always_creates_customer_with_hashed_password():
    user_id = uuid4()
    now = datetime.now(timezone.utc)
    user = SimpleNamespace(
        id=user_id,
        phone="0901234567",
        name="Khach hang",
        email=None,
        business_id=None,
        default_venue_id=None,
        role=UserRole.CUSTOMER,
        created_at=now,
        updated_at=now,
    )
    repo = SimpleNamespace(
        get_by_phone=AsyncMock(return_value=None),
        create=AsyncMock(return_value=user),
    )

    with patch("app.api.auth.UserRepository", return_value=repo):
        response = await register(
            UserRegister(
                phone="+84 90 123 4567",
                name="Khach hang",
                password="password123",
            ),
            AsyncMock(),
        )

    create_data = repo.create.await_args.args[0]
    assert create_data["phone"] == "0901234567"
    assert create_data["role"] is UserRole.CUSTOMER
    assert create_data["password_hash"] != "password123"
    assert verify_password("password123", create_data["password_hash"])
    assert response.user.role is UserRole.CUSTOMER
    assert response.token == f"user:{user_id}"


@pytest.mark.asyncio
async def test_register_rejects_duplicate_phone():
    repo = SimpleNamespace(get_by_phone=AsyncMock(return_value=object()))

    with patch("app.api.auth.UserRepository", return_value=repo):
        with pytest.raises(HTTPException) as exc_info:
            await register(
                UserRegister(
                    phone="0901234567",
                    name="Khach hang",
                    password="password123",
                ),
                AsyncMock(),
            )

    assert exc_info.value.status_code == 409


@pytest.mark.asyncio
async def test_register_handles_concurrent_duplicate_phone():
    session = AsyncMock()
    repo = SimpleNamespace(
        get_by_phone=AsyncMock(return_value=None),
        create=AsyncMock(side_effect=IntegrityError("insert", {}, Exception())),
    )

    with patch("app.api.auth.UserRepository", return_value=repo):
        with pytest.raises(HTTPException) as exc_info:
            await register(
                UserRegister(
                    phone="0901234567",
                    name="Khach hang",
                    password="password123",
                ),
                session,
            )

    assert exc_info.value.status_code == 409
    session.rollback.assert_awaited_once()
