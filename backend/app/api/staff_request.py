from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user, require_roles
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.repositories.notification_repository import NotificationRepository
from app.repositories.staff_request_repository import StaffRequestRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.staff_request import (
    StaffRequestActionResponse,
    StaffRequestCreate,
    StaffRequestResponse,
)
from app.services.notification_service import NotificationService
from app.services.staff_request_service import StaffRequestService

router = APIRouter(prefix="/api/staff/requests", tags=["staff-requests"])


def _get_service(session: AsyncSession) -> StaffRequestService:
    venue_repo = VenueRepository(session)
    return StaffRequestService(
        repo=StaffRequestRepository(session),
        notification_service=NotificationService(
            NotificationRepository(session),
            venue_repo,
        ),
        venue_repo=venue_repo,
    )


@router.post("", response_model=StaffRequestResponse, status_code=201)
async def create_staff_request(
    data: StaffRequestCreate,
    _: None = Depends(rate_limit(limit=5, window_seconds=60, scope="staff_request")),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> StaffRequestResponse:
    """Create a new staff assistance request (customer-facing)."""
    service = _get_service(session)

    existing = await service.get_active_user_request(str(user.id))
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Bạn đang có yêu cầu chưa hoàn thành. Vui lòng chờ hoặc hủy yêu cầu trước.",
        )

    allowed_types = {"order", "payment", "help", "maintenance", "other"}
    if data.request_type not in allowed_types:
        raise HTTPException(
            status_code=422,
            detail=f"request_type must be one of {allowed_types}",
        )

    result = await service.create_request(
        user_id=str(user.id),
        user_name=user.name,
        request_type=data.request_type,
        description=data.description,
        table_number=data.table_number,
        venue_id=data.venue_id,
        resource_id=data.resource_id,
        resource_label=data.resource_label,
        user=user,
    )
    await session.commit()
    return result


@router.get("/mine", response_model=list[StaffRequestResponse])
async def get_my_requests(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[StaffRequestResponse]:
    """Get current user's staff requests."""
    service = _get_service(session)
    return await service.get_user_requests(str(user.id))


@router.get("/pending", response_model=list[StaffRequestResponse])
async def get_pending_requests(
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> list[StaffRequestResponse]:
    """Get all pending staff requests (staff/admin only)."""
    service = _get_service(session)
    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_value == "STAFF":
        return await service.get_pending_requests_for_staff(str(user.id))
    return await service.get_pending_requests()


@router.patch("/{request_id}/accept", response_model=StaffRequestResponse)
async def accept_staff_request(
    request_id: str,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> StaffRequestResponse:
    """Accept a pending staff request (staff/admin only)."""
    service = _get_service(session)
    request_repo = StaffRequestRepository(session)
    request = await request_repo.get_by_id(request_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_value == "STAFF":
        venue_repo = VenueRepository(session)
        access = await venue_repo.get_staff_access(str(user.id))
        if access.has_assignments:
            resource_ids = await venue_repo.expand_accessible_resource_ids(access)
            can_accept = False
            if request.resource_id and request.resource_id in resource_ids:
                can_accept = True
            if request.venue_id and request.venue_id in access.venue_scope_ids:
                can_accept = True
            if not can_accept:
                raise HTTPException(
                    status_code=403,
                    detail="Request is outside your assigned tables/courts",
                )
    try:
        result = await service.accept_request(
            request_id, str(user.id), user.name
        )
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/{request_id}/complete", response_model=StaffRequestResponse)
async def complete_staff_request(
    request_id: str,
    user: User = Depends(require_roles("STAFF", "ADMIN")),
    session: AsyncSession = Depends(get_db),
) -> StaffRequestResponse:
    """Mark an accepted staff request as completed (staff/admin only)."""
    service = _get_service(session)
    try:
        result = await service.complete_request(request_id)
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/{request_id}/cancel", response_model=StaffRequestResponse)
async def cancel_staff_request(
    request_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> StaffRequestResponse:
    """Cancel a staff request (customer or staff)."""
    service = _get_service(session)
    request_repo = StaffRequestRepository(session)
    request = await request_repo.get_by_id(request_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
    if str(request.user_id) != str(user.id) and role_value not in {"STAFF", "ADMIN"}:
        raise HTTPException(status_code=403, detail="Not authorized")

    try:
        result = await service.cancel_request(request_id)
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
