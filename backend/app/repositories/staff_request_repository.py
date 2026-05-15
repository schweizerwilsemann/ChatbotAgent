import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.staff_request import StaffRequest


class StaffRequestRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        user_id: str,
        user_name: str | None,
        request_type: str,
        description: str | None,
        table_number: int | None,
    ) -> StaffRequest:
        request = StaffRequest(
            id=uuid.uuid4(),
            user_id=user_id,
            user_name=user_name,
            request_type=request_type,
            description=description,
            table_number=table_number,
            status="pending",
        )
        self._session.add(request)
        await self._session.flush()
        return request

    async def get_by_id(self, request_id: str) -> StaffRequest | None:
        stmt = select(StaffRequest).where(StaffRequest.id == uuid.UUID(request_id))
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_pending(self, limit: int = 50) -> list[StaffRequest]:
        stmt = (
            select(StaffRequest)
            .where(StaffRequest.status == "pending")
            .order_by(StaffRequest.created_at.asc())
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_by_user(self, user_id: str, limit: int = 20) -> list[StaffRequest]:
        stmt = (
            select(StaffRequest)
            .where(StaffRequest.user_id == user_id)
            .order_by(StaffRequest.created_at.desc())
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_active_by_user(self, user_id: str) -> StaffRequest | None:
        stmt = (
            select(StaffRequest)
            .where(
                StaffRequest.user_id == user_id,
                StaffRequest.status == "pending",
            )
            .order_by(StaffRequest.created_at.desc())
            .limit(1)
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def accept(
        self, request_id: str, staff_id: str, staff_name: str | None
    ) -> StaffRequest | None:
        request = await self.get_by_id(request_id)
        if not request or request.status != "pending":
            return None
        request.status = "accepted"
        request.accepted_by = staff_id
        request.accepted_by_name = staff_name
        request.accepted_at = datetime.now(timezone.utc)
        await self._session.flush()
        return request

    async def complete(self, request_id: str) -> StaffRequest | None:
        request = await self.get_by_id(request_id)
        if not request or request.status != "accepted":
            return None
        request.status = "completed"
        request.completed_at = datetime.now(timezone.utc)
        await self._session.flush()
        return request

    async def cancel(self, request_id: str) -> StaffRequest | None:
        request = await self.get_by_id(request_id)
        if not request or request.status not in ("pending", "accepted"):
            return None
        request.status = "cancelled"
        await self._session.flush()
        return request
