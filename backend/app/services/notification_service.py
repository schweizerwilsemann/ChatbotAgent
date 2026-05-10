import json
import logging
from datetime import datetime, timezone
from typing import Any

from app.core.redis_client import redis_client
from app.repositories.notification_repository import NotificationRepository
from app.schemas.notification import NotificationResponse
from app.services.realtime import realtime_manager

logger = logging.getLogger(__name__)

OPERATIONS_ROLES = ["STAFF", "ADMIN"]


class NotificationService:
    def __init__(self, repo: NotificationRepository) -> None:
        self._repo = repo

    async def notify_operations(
        self,
        *,
        event_type: str,
        title: str,
        message: str,
        source: str,
        payload: dict[str, Any],
    ) -> NotificationResponse:
        notification = await self._repo.create(
            event_type=event_type,
            title=title,
            message=message,
            target_roles=OPERATIONS_ROLES,
            source=source,
            payload=payload,
        )
        response = self.to_response(notification)
        await self.publish(response)
        return response

    async def list_for_operations(self, limit: int = 50) -> list[NotificationResponse]:
        notifications = await self._repo.list_for_roles(OPERATIONS_ROLES, limit=limit)
        return [self.to_response(notification) for notification in notifications]

    async def publish(self, notification: NotificationResponse) -> None:
        payload = notification.model_dump(mode="json")
        await realtime_manager.broadcast_to_roles(notification.target_roles, payload)
        try:
            await redis_client.set(
                f"staff_notification:{notification.id}",
                json.dumps(payload, ensure_ascii=False),
                ex=3600,
            )
            await redis_client.publish("staff_notifications", payload)
        except Exception:
            logger.debug("Notification Redis publish skipped", exc_info=True)

    @staticmethod
    def to_response(notification) -> NotificationResponse:
        return NotificationResponse(
            id=str(notification.id),
            event_type=notification.event_type,
            title=notification.title,
            message=notification.message,
            target_roles=notification.target_roles,
            source=notification.source,
            payload=notification.payload,
            created_at=getattr(notification, "created_at", None)
            or datetime.now(timezone.utc),
            read_at=notification.read_at,
        )
