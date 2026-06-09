import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.camera import Camera, CameraBrand
from app.models.venue import ServiceResource, VenueArea


BRAND_RTSP_TEMPLATES = {
    CameraBrand.HIK: "rtsp://{username}:{password}@{ip}:{port}/cam/realmonitor?channel=1&subtype=0",
    CameraBrand.DAHUA: "rtsp://{username}:{password}@{ip}:{port}/cam/realmonitor?channel=1&subtype=0",
    CameraBrand.SEETONG: "rtsp://{username}:{password}@{ip}:{port}/mpeg4",
    CameraBrand.FPT: "rtsp://{username}:{password}@{ip}:{port}/live/0",
}


def build_rtsp_url(camera: Camera) -> str:
    if camera.rtsp_url_override:
        return camera.rtsp_url_override
    template = BRAND_RTSP_TEMPLATES.get(camera.camera_brand)
    if template:
        return template.format(
            username=camera.username,
            password=camera.password,
            ip=camera.ip_address,
            port=camera.port,
        )
    return f"rtsp://{camera.username}:{camera.password}@{camera.ip_address}:{camera.port}/"


class CameraRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, camera_id: str | uuid.UUID) -> Camera | None:
        try:
            camera_uuid = _to_uuid(camera_id)
        except ValueError:
            return None
        stmt = select(Camera).where(
            Camera.id == camera_uuid,
            Camera.is_deleted.is_(False),
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_cameras(
        self,
        *,
        venue_id: str | uuid.UUID | None = None,
        resource_id: str | uuid.UUID | None = None,
        is_active: bool | None = True,
    ) -> list[dict]:
        stmt = (
            select(Camera, ServiceResource.name.label("resource_name"))
            .outerjoin(ServiceResource, Camera.resource_id == ServiceResource.id)
            .where(Camera.is_deleted.is_(False))
            .order_by(Camera.name.asc())
        )
        if venue_id:
            stmt = stmt.where(Camera.venue_id == _to_uuid(venue_id))
        if resource_id:
            stmt = stmt.where(Camera.resource_id == _to_uuid(resource_id))
        if is_active is not None:
            stmt = stmt.where(Camera.is_active == is_active)

        result = await self._session.execute(stmt)
        return [
            {"camera": row[0], "resource_name": row[1]}
            for row in result.all()
        ]

    async def list_cameras_for_resources(
        self,
        resource_ids: set[uuid.UUID],
    ) -> list[dict]:
        if not resource_ids:
            return []
        stmt = (
            select(Camera, ServiceResource.name.label("resource_name"))
            .outerjoin(ServiceResource, Camera.resource_id == ServiceResource.id)
            .where(
                Camera.is_deleted.is_(False),
                Camera.is_active.is_(True),
                Camera.resource_id.in_(list(resource_ids)),
            )
            .order_by(Camera.name.asc())
        )
        result = await self._session.execute(stmt)
        return [
            {"camera": row[0], "resource_name": row[1]}
            for row in result.all()
        ]

    async def list_cameras_for_venues(
        self,
        venue_ids: set[uuid.UUID],
    ) -> list[dict]:
        if not venue_ids:
            return []
        stmt = (
            select(Camera, ServiceResource.name.label("resource_name"))
            .outerjoin(ServiceResource, Camera.resource_id == ServiceResource.id)
            .where(
                Camera.is_deleted.is_(False),
                Camera.is_active.is_(True),
                Camera.venue_id.in_(list(venue_ids)),
            )
            .order_by(Camera.name.asc())
        )
        result = await self._session.execute(stmt)
        return [
            {"camera": row[0], "resource_name": row[1]}
            for row in result.all()
        ]

    async def create_camera(
        self,
        *,
        venue_id: str,
        resource_id: str | None,
        name: str,
        ip_address: str,
        port: int,
        username: str,
        password: str,
        camera_brand: str,
        rtsp_url_override: str | None,
    ) -> Camera:
        camera = Camera(
            id=uuid.uuid4(),
            venue_id=_to_uuid(venue_id),
            resource_id=_to_uuid(resource_id) if resource_id else None,
            name=name,
            ip_address=ip_address,
            port=port,
            username=username,
            password=password,
            camera_brand=CameraBrand(camera_brand),
            rtsp_url_override=rtsp_url_override,
            is_active=True,
        )
        self._session.add(camera)
        await self._session.flush()
        return camera

    async def update_camera(
        self,
        camera_id: str | uuid.UUID,
        **fields,
    ) -> Camera | None:
        camera = await self.get_by_id(camera_id)
        if not camera:
            return None
        for key, value in fields.items():
            if value is not None and hasattr(camera, key):
                if key == "camera_brand":
                    value = CameraBrand(value)
                if key == "resource_id":
                    value = _to_uuid(value) if value else None
                setattr(camera, key, value)
        await self._session.flush()
        return camera

    async def delete_camera(self, camera_id: str | uuid.UUID) -> bool:
        camera = await self.get_by_id(camera_id)
        if not camera:
            return False
        camera.is_deleted = True
        from datetime import datetime, timezone
        camera.deleted_at = datetime.now(timezone.utc)
        await self._session.flush()
        return True


def _to_uuid(value: str | uuid.UUID) -> uuid.UUID:
    if isinstance(value, uuid.UUID):
        return value
    return uuid.UUID(str(value))
