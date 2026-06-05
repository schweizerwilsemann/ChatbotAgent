import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, user_data: dict) -> User:
        user = User(id=uuid.uuid4(), **user_data)
        self._session.add(user)
        await self._session.flush()
        return user

    async def get_by_id(self, user_id: str) -> User | None:
        stmt = select(User).where(User.id == uuid.UUID(user_id))
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_phone(self, phone: str) -> User | None:
        stmt = select(User).where(User.phone == phone)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def update_password_hash(self, user_id: str, password_hash: str) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        user.password_hash = password_hash
        await self._session.flush()
        return user

    async def update_stripe_customer_id(
        self,
        user_id: str,
        stripe_customer_id: str,
    ) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        user.stripe_customer_id = stripe_customer_id
        await self._session.flush()
        return user
