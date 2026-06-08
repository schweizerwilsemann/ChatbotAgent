from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user, require_roles
from app.core.database import get_db
from app.models.user import User
from app.repositories.venue_repository import VenueRepository
from app.schemas.venue import (
    ServiceResourceCreate,
    ServiceResourceResponse,
    ServiceResourceUpdate,
    StaffAssignmentCreate,
    StaffAssignmentResponse,
    VenueResponse,
)

router = APIRouter(prefix="/api", tags=["venues"])


def _venue_response(venue) -> VenueResponse:
    return VenueResponse(
        id=str(venue.id),
        business_id=str(venue.business_id),
        name=venue.name,
        address=venue.address,
        timezone=venue.timezone,
        is_active=venue.is_active,
    )


def _resource_response(entry: dict) -> ServiceResourceResponse:
    resource = entry["resource"]
    area_name = entry.get("area_name")
    label = resource.name if not area_name else f"{resource.name} · {area_name}"
    return ServiceResourceResponse(
        id=str(resource.id),
        venue_id=str(resource.venue_id),
        area_id=str(resource.area_id) if resource.area_id else None,
        area_name=area_name,
        code=resource.code,
        name=resource.name,
        label=label,
        resource_type=resource.resource_type.value
        if hasattr(resource.resource_type, "value")
        else str(resource.resource_type),
        sport_type=resource.sport_type,
        number=resource.number,
        capacity=resource.capacity,
        status=resource.status.value
        if hasattr(resource.status, "value")
        else str(resource.status),
        metadata=resource.resource_metadata or {},
        hourly_rate=resource.hourly_rate,
    )


def _assignment_response(assignment) -> StaffAssignmentResponse:
    return StaffAssignmentResponse(
        id=str(assignment.id),
        staff_id=assignment.staff_id,
        venue_id=str(assignment.venue_id),
        area_id=str(assignment.area_id) if assignment.area_id else None,
        resource_id=str(assignment.resource_id) if assignment.resource_id else None,
        scope=assignment.scope.value
        if hasattr(assignment.scope, "value")
        else str(assignment.scope),
        starts_at=assignment.starts_at,
        ends_at=assignment.ends_at,
        is_active=assignment.is_active,
    )


@router.get("/venues", response_model=list[VenueResponse])
async def list_venues(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[VenueResponse]:
    repo = VenueRepository(session)
    venues = await repo.list_venues_for_user(user)
    return [_venue_response(venue) for venue in venues]


@router.get("/venues/resources", response_model=list[ServiceResourceResponse])
async def list_resources(
    venue_id: str | None = Query(None),
    sport_type: str | None = Query(None),
    resource_type: str | None = Query(None),
    status: str | None = Query("active"),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[ServiceResourceResponse]:
    repo = VenueRepository(session)
    resolved_venue_id = await repo.resolve_user_venue_id(
        user,
        explicit_venue_id=venue_id,
    )
    rows = await repo.list_resources(
        venue_id=str(resolved_venue_id) if resolved_venue_id else venue_id,
        sport_type=sport_type,
        resource_type=resource_type,
        status=status,
    )

    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_value == "STAFF":
        access = await repo.get_staff_access(str(user.id))
        if access.has_assignments:
            resource_ids = await repo.expand_accessible_resource_ids(access)
            rows = [
                row
                for row in rows
                if row["resource"].venue_id in access.venue_scope_ids
                or row["resource"].id in resource_ids
            ]

    return [_resource_response(row) for row in rows]


@router.post(
    "/admin/resources",
    response_model=ServiceResourceResponse,
    status_code=201,
)
async def create_resource(
    data: ServiceResourceCreate,
    _: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> ServiceResourceResponse:
    repo = VenueRepository(session)
    venue = await repo.get_venue_by_id(data.venue_id)
    if not venue:
        raise HTTPException(status_code=404, detail="Venue not found")
    resource = await repo.create_resource(**data.model_dump())
    result = _resource_response({"resource": resource, "area_name": None})
    await session.commit()
    return result


@router.patch(
    "/admin/resources/{resource_id}",
    response_model=ServiceResourceResponse,
)
async def update_resource(
    resource_id: str,
    data: ServiceResourceUpdate,
    _: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> ServiceResourceResponse:
    repo = VenueRepository(session)
    update_data = data.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    resource = await repo.update_resource(resource_id, **update_data)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    result = _resource_response({"resource": resource, "area_name": None})
    await session.commit()
    return result


@router.get(
    "/admin/staff-assignments",
    response_model=list[StaffAssignmentResponse],
)
async def list_staff_assignments(
    staff_id: str | None = Query(None),
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[StaffAssignmentResponse]:
    repo = VenueRepository(session)
    venue_scope_ids = None
    if user.default_venue_id:
        venue_scope_ids = {user.default_venue_id}
    assignments = await repo.list_staff_assignments(staff_id=staff_id)
    if venue_scope_ids is not None:
        assignments = [a for a in assignments if a.venue_id in venue_scope_ids]
    return [_assignment_response(assignment) for assignment in assignments]


@router.post(
    "/admin/staff-assignments",
    response_model=StaffAssignmentResponse,
    status_code=201,
)
async def create_staff_assignment(
    data: StaffAssignmentCreate,
    user: User = Depends(require_roles("ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> StaffAssignmentResponse:
    repo = VenueRepository(session)
    venue_id = data.venue_id
    if user.default_venue_id:
        venue_id = str(user.default_venue_id)
    venue = await repo.get_venue_by_id(venue_id)
    if not venue:
        raise HTTPException(status_code=404, detail="Venue not found")
    if data.resource_id and not await repo.get_resource_by_id(data.resource_id):
        raise HTTPException(status_code=404, detail="Resource not found")
    assignment = await repo.create_staff_assignment(
        staff_id=data.staff_id,
        venue_id=venue_id,
        area_id=data.area_id,
        resource_id=data.resource_id,
        scope=data.scope,
        starts_at=data.starts_at,
        ends_at=data.ends_at,
    )
    result = _assignment_response(assignment)
    await session.commit()
    return result
