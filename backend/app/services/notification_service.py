import json
import logging
from datetime import datetime, timezone
from typing import Any

from app.core.redis_client import redis_client
from app.repositories.notification_repository import NotificationRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.notification import NotificationResponse
from app.services.realtime import realtime_manager

logger = logging.getLogger(__name__)

OPERATIONS_ROLES = ["STAFF", "ADMIN"]


class NotificationService:
    def __init__(
        self,
        repo: NotificationRepository,
        venue_repo: VenueRepository | None = None,
    ) -> None:
        self._repo = repo
        self._venue_repo = venue_repo

    async def notify_operations(
        self,
        *,
        event_type: str,
        title: str,
        message: str,
        source: str,
        payload: dict[str, Any],
    ) -> NotificationResponse:
        if self._venue_repo and "target_user_ids" not in payload:
            target_user_ids = await self._venue_repo.list_staff_ids_for_resource(
                venue_id=_optional_payload_id(payload.get("venue_id")),
                resource_id=_optional_payload_id(payload.get("resource_id")),
            )
            if target_user_ids:
                payload = dict(payload)
                payload["target_user_ids"] = target_user_ids

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

    async def notify_user(
        self,
        *,
        event_type: str,
        title: str,
        message: str,
        target_roles: list[str],
        source: str,
        target_user_id: str,
        payload: dict[str, Any],
    ) -> NotificationResponse:
        targeted_payload = dict(payload)
        targeted_payload["target_user_ids"] = [target_user_id]

        notification = await self._repo.create(
            event_type=event_type,
            title=title,
            message=message,
            target_roles=target_roles,
            source=source,
            payload=targeted_payload,
        )
        response = self.to_response(notification)
        await self.publish(response)
        return response

    async def list_for_operations(
        self,
        limit: int = 50,
        offset: int = 0,
        user=None,
    ) -> list[NotificationResponse]:
        role_value = user.role.value if user and hasattr(user.role, "value") else (
            str(user.role) if user else None
        )
        default_venue_id = getattr(user, "default_venue_id", None) if user else None
        if (
            not user
            or not self._venue_repo
            or (role_value == "ADMIN" and not default_venue_id)
        ):
            notifications = await self._repo.list_for_roles(
                OPERATIONS_ROLES,
                limit=limit,
                offset=offset,
            )
            return [self.to_response(notification) for notification in notifications]

        if role_value not in {"STAFF", "ADMIN"}:
            return []

        visible: list[NotificationResponse] = []
        batch_size = max(limit, 50)
        scan_offset = 0
        target_count = offset + limit
        while len(visible) < target_count:
            batch = await self._repo.list_for_roles(
                OPERATIONS_ROLES,
                limit=batch_size,
                offset=scan_offset,
            )
            if not batch:
                break
            for notification in batch:
                response = self.to_response(notification)
                if await self._is_visible_to_operations_user(
                    user,
                    response.payload,
                ):
                    visible.append(response)
                    if len(visible) >= target_count:
                        break
            if len(batch) < batch_size:
                break
            scan_offset += len(batch)
        return visible[offset:target_count]

    async def update_request_status(
        self, request_id: str, status: str
    ) -> None:
        await self._repo.update_payload_by_request_id(
            "staff_request", request_id, status
        )

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

    async def _is_visible_to_operations_user(
        self,
        user,
        payload: dict[str, Any],
    ) -> bool:
        user_id = str(user.id)
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        target_user_ids = payload.get("target_user_ids")
        if isinstance(target_user_ids, list) and target_user_ids:
            return user_id in {str(target_id) for target_id in target_user_ids}

        resource_id = _optional_payload_id(payload.get("resource_id"))
        venue_id = _optional_payload_id(payload.get("venue_id"))
        if not resource_id and not venue_id:
            return True

        if role_value == "ADMIN":
            default_venue_id = getattr(user, "default_venue_id", None)
            if not default_venue_id:
                return True
            default_venue_id = str(default_venue_id)
            if venue_id and venue_id == default_venue_id:
                return True
            if resource_id:
                resource = await self._venue_repo.get_resource_by_id(resource_id)
                return bool(resource and str(resource.venue_id) == default_venue_id)
            return False

        access = await self._venue_repo.get_staff_access(user_id)
        if not access.has_assignments:
            default_venue_id = getattr(user, "default_venue_id", None)
            if not default_venue_id:
                return False
            default_venue_id = str(default_venue_id)
            if venue_id and venue_id == default_venue_id:
                return True
            if resource_id:
                resource = await self._venue_repo.get_resource_by_id(resource_id)
                return bool(resource and str(resource.venue_id) == default_venue_id)
            return False

        resource_ids = await self._venue_repo.expand_accessible_resource_ids(access)
        if resource_id and resource_id in {str(item) for item in resource_ids}:
            return True
        if venue_id and venue_id in {str(item) for item in access.venue_scope_ids}:
            return True
        return False


def _optional_payload_id(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
