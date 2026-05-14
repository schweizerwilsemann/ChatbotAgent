import uuid
from datetime import datetime, timezone

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

    async def mark_as_read(self, notification_id: str) -> Notification | None:
        """Mark a single notification as read."""
        stmt = select(Notification).where(Notification.id == uuid.UUID(notification_id))
        result = await self._session.execute(stmt)
        notification = result.scalar_one_or_none()
        if not notification:
            return None
        notification.read_at = datetime.now(timezone.utc)
        await self._session.flush()
        return notification

    async def mark_all_as_read(self, roles: list[str]) -> int:
        """Mark all unread notifications for the given roles as read.
        Returns the number of notifications updated."""
        now = datetime.now(timezone.utc)
        role_set = set(roles)
        # Fetch all unread notifications, filter by role in Python
        stmt = (
            select(Notification)
            .where(Notification.read_at.is_(None))
            .order_by(Notification.created_at.desc())
            .limit(200)
        )
        result = await self._session.execute(stmt)
        count = 0
        for notification in result.scalars().all():
            if role_set.intersection(notification.target_roles or []):
                notification.read_at = now
                count += 1
        await self._session.flush()
        return count
