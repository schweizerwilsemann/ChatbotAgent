from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user, require_roles
from app.core.database import get_db
from app.models.user import User
from app.repositories.camera_repository import CameraRepository, build_rtsp_url
from app.repositories.venue_repository import VenueRepository
from app.schemas.camera import CameraCreate, CameraResponse, CameraUpdate

router = APIRouter(prefix="/api", tags=["cameras"])


def _camera_response(entry: dict) -> CameraResponse:
    camera = entry["camera"]
    resource_name = entry.get("resource_name")
    return CameraResponse(
        id=str(camera.id),
        venue_id=str(camera.venue_id),
        resource_id=str(camera.resource_id) if camera.resource_id else None,
        resource_label=resource_name,
        name=camera.name,
        ip_address=camera.ip_address,
        port=camera.port,
        username=camera.username,
        camera_brand=camera.camera_brand.value
        if hasattr(camera.camera_brand, "value")
        else str(camera.camera_brand),
        rtsp_url=build_rtsp_url(camera),
        is_active=camera.is_active,
    )


@router.get("/admin/cameras", response_model=list[CameraResponse])
async def list_cameras(
    venue_id: str | None = Query(None),
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[CameraResponse]:
    cam_repo = CameraRepository(session)
    resolved_venue_id = venue_id
    if not resolved_venue_id and user.default_venue_id:
        resolved_venue_id = str(user.default_venue_id)
    entries = await cam_repo.list_cameras(venue_id=resolved_venue_id)
    return [_camera_response(e) for e in entries]


@router.post("/admin/cameras", response_model=CameraResponse, status_code=201)
async def create_camera(
    data: CameraCreate,
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> CameraResponse:
    venue_repo = VenueRepository(session)
    venue_id = data.venue_id or (str(user.default_venue_id) if user.default_venue_id else None)
    if not venue_id:
        raise HTTPException(status_code=400, detail="venue_id is required")
    venue = await venue_repo.get_venue_by_id(venue_id)
    if not venue:
        raise HTTPException(status_code=404, detail="Venue not found")
    if data.resource_id:
        resource = await venue_repo.get_resource_by_id(data.resource_id)
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")

    cam_repo = CameraRepository(session)
    camera = await cam_repo.create_camera(
        venue_id=venue_id,
        resource_id=data.resource_id,
        name=data.name,
        ip_address=data.ip_address,
        port=data.port,
        username=data.username,
        password=data.password,
        camera_brand=data.camera_brand,
        rtsp_url_override=data.rtsp_url_override,
    )
    await session.flush()
    result = _camera_response({"camera": camera, "resource_name": None})
    await session.commit()
    return result


@router.patch("/admin/cameras/{camera_id}", response_model=CameraResponse)
async def update_camera(
    camera_id: str,
    data: CameraUpdate,
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> CameraResponse:
    cam_repo = CameraRepository(session)
    camera = await cam_repo.get_by_id(camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    if user.default_venue_id and camera.venue_id != user.default_venue_id:
        raise HTTPException(status_code=403, detail="Cannot modify camera from another venue")
    update_data = data.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    camera = await cam_repo.update_camera(camera_id, **update_data)
    await session.flush()
    result = _camera_response({"camera": camera, "resource_name": None})
    await session.commit()
    return result


@router.delete("/admin/cameras/{camera_id}", status_code=204)
async def delete_camera(
    camera_id: str,
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> None:
    cam_repo = CameraRepository(session)
    camera = await cam_repo.get_by_id(camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    if user.default_venue_id and camera.venue_id != user.default_venue_id:
        raise HTTPException(status_code=403, detail="Cannot delete camera from another venue")
    await cam_repo.delete_camera(camera_id)
    await session.commit()


@router.get("/staff/cameras", response_model=list[CameraResponse])
async def list_staff_cameras(
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[CameraResponse]:
    cam_repo = CameraRepository(session)
    venue_repo = VenueRepository(session)

    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)

    if role_value == "ADMIN":
        if user.default_venue_id:
            entries = await cam_repo.list_cameras(
                venue_id=str(user.default_venue_id),
                is_active=True,
            )
        else:
            entries = await cam_repo.list_cameras(is_active=True)
        return [_camera_response(e) for e in entries]

    access = await venue_repo.get_staff_access(str(user.id))
    if not access.has_assignments:
        return []

    if access.venue_scope_ids:
        entries = await cam_repo.list_cameras_for_venues(access.venue_scope_ids)
    else:
        resource_ids = await venue_repo.expand_accessible_resource_ids(access)
        entries = await cam_repo.list_cameras_for_resources(resource_ids)

    return [_camera_response(e) for e in entries]
