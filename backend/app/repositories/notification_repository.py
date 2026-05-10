import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification


class NotificationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        event_type: str,
        title: str,
        message: str,
        target_roles: list[str],
        source: str,
        payload: dict,
    ) -> Notification:
        notification = Notification(
            id=uuid.uuid4(),
            event_type=event_type,
            title=title,
            message=message,
            target_roles=target_roles,
            source=source,
            payload=payload,
        )
        self._session.add(notification)
        await self._session.flush()
        return notification

    async def list_for_roles(
        self,
        roles: list[str],
        limit: int = 50,
    ) -> list[Notification]:
        stmt = (
            select(Notification)
            .order_by(Notification.created_at.desc())
            .limit(max(limit * 4, limit))
        )
        result = await self._session.execute(stmt)
        role_set = set(roles)
        notifications = [
            notification
            for notification in result.scalars().all()
            if role_set.intersection(notification.target_roles or [])
        ]
        return notifications[:limit]
