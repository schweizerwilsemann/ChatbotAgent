import uuid

from app.core.database import get_db
from app.core.security import create_dev_token, parse_dev_token, verify_password
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.user import AuthResponse, UserLogin, UserResponse
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api", tags=["auth"])


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization token")

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid authorization token")
    return token


async def _get_user_from_token(
    authorization: str | None,
    session: AsyncSession,
) -> User:
    token = _extract_bearer_token(authorization)
    user_id = parse_dev_token(token)
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid authorization token")

    repo = UserRepository(session)
    user = await repo.get_by_id(str(user_id))
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user


@router.post("/auth/login", response_model=AuthResponse)
async def login(
    data: UserLogin,
    session: AsyncSession = Depends(get_db),
) -> AuthResponse:
    repo = UserRepository(session)
    user = await repo.get_by_phone(data.phone)
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid phone or password")

    return AuthResponse(user=user, token=create_dev_token(user.id))


@router.get("/auth/verify", response_model=UserResponse)
async def verify_token(
    authorization: str | None = Header(default=None),
    session: AsyncSession = Depends(get_db),
) -> User:
    return await _get_user_from_token(authorization, session)


@router.get("/user/profile/{user_id}", response_model=UserResponse)
async def get_profile(
    user_id: uuid.UUID,
    authorization: str | None = Header(default=None),
    session: AsyncSession = Depends(get_db),
) -> User:
    user = await _get_user_from_token(authorization, session)
    if user.id != user_id:
        raise HTTPException(status_code=403, detail="Cannot access another user profile")
    return user
