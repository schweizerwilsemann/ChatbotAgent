import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, or_, select
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
        venue_id: str | uuid.UUID | None = None,
        resource_id: str | uuid.UUID | None = None,
        resource_label: str | None = None,
    ) -> StaffRequest:
        request = StaffRequest(
            id=uuid.uuid4(),
            user_id=user_id,
            user_name=user_name,
            venue_id=_to_uuid_or_none(venue_id),
            resource_id=_to_uuid_or_none(resource_id),
            resource_label=resource_label,
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

    async def get_pending_for_assignment(
        self,
        *,
        venue_scope_ids: set[uuid.UUID],
        resource_ids: set[uuid.UUID],
        limit: int = 50,
    ) -> list[StaffRequest]:
        conditions = [StaffRequest.status == "pending"]
        scope_conditions = []
        if venue_scope_ids:
            scope_conditions.append(StaffRequest.venue_id.in_(list(venue_scope_ids)))
        if resource_ids:
            scope_conditions.append(StaffRequest.resource_id.in_(list(resource_ids)))
        if scope_conditions:
            conditions.append(or_(*scope_conditions))
        else:
            conditions.append(StaffRequest.resource_id.is_(None))

        stmt = (
            select(StaffRequest)
            .where(and_(*conditions))
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


def _to_uuid_or_none(value: str | uuid.UUID | None) -> uuid.UUID | None:
    if value is None:
        return None
    if isinstance(value, uuid.UUID):
        return value
    return uuid.UUID(str(value))

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
