import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.venue import (
    Business,
    ResourceStatus,
    ResourceType,
    ServiceResource,
    StaffAssignment,
    StaffAssignmentScope,
    Venue,
    VenueArea,
)


COURT_TYPE_TO_RESOURCE_TYPE = {
    "billiards": ResourceType.BILLIARDS_TABLE,
    "pickleball": ResourceType.PICKLEBALL_COURT,
    "badminton": ResourceType.BADMINTON_COURT,
}


class VenueRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_default_business(self) -> Business | None:
        stmt = select(Business).order_by(Business.created_at.asc()).limit(1)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_default_venue(self) -> Venue | None:
        stmt = select(Venue).order_by(Venue.created_at.asc()).limit(1)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_venue_by_id(self, venue_id: str | uuid.UUID) -> Venue | None:
        stmt = select(Venue).where(Venue.id == _to_uuid(venue_id))
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_resource_by_id(
        self,
        resource_id: str | uuid.UUID,
    ) -> ServiceResource | None:
        try:
            resource_uuid = _to_uuid(resource_id)
        except ValueError:
            return None
        stmt = select(ServiceResource).where(ServiceResource.id == resource_uuid)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def resolve_user_venue_id(
        self,
        user: User | None = None,
        explicit_venue_id: str | None = None,
    ) -> uuid.UUID | None:
        if explicit_venue_id:
            return _to_uuid(explicit_venue_id)

        if user is not None:
            default_venue_id = getattr(user, "default_venue_id", None)
            if default_venue_id:
                return _to_uuid(default_venue_id)

        default_venue = await self.get_default_venue()
        return default_venue.id if default_venue else None

    async def list_venues_for_user(self, user: User) -> list[Venue]:
        role_value = user.role.value if hasattr(user.role, "value") else str(user.role)
        business_id = getattr(user, "business_id", None)

        stmt = select(Venue).where(Venue.is_active.is_(True))
        if business_id:
            stmt = stmt.where(Venue.business_id == _to_uuid(business_id))

        if role_value == "STAFF":
            access = await self.get_staff_access(str(user.id))
            if access.has_assignments:
                stmt = stmt.where(Venue.id.in_(list(access.venue_ids)))

        stmt = stmt.order_by(Venue.name.asc())
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def list_resources(
        self,
        *,
        venue_id: str | uuid.UUID | None = None,
        sport_type: str | None = None,
        resource_type: str | None = None,
        status: str | None = "active",
    ) -> list[dict]:
        stmt = (
            select(ServiceResource, VenueArea.name.label("area_name"))
            .outerjoin(VenueArea, ServiceResource.area_id == VenueArea.id)
            .order_by(
                ServiceResource.resource_type.asc(),
                ServiceResource.number.asc(),
                ServiceResource.code.asc(),
            )
        )
        if venue_id:
            stmt = stmt.where(ServiceResource.venue_id == _to_uuid(venue_id))
        if sport_type:
            stmt = stmt.where(ServiceResource.sport_type == sport_type.lower())
        if resource_type:
            stmt = stmt.where(ServiceResource.resource_type == ResourceType(resource_type))
        if status:
            stmt = stmt.where(ServiceResource.status == ResourceStatus(status))

        result = await self._session.execute(stmt)
        return [
            {"resource": row[0], "area_name": row[1]}
            for row in result.all()
        ]

    async def resolve_legacy_resource(
        self,
        *,
        venue_id: str | uuid.UUID | None,
        court_type: str | None = None,
        table_number: int | None = None,
        court_number: int | None = None,
    ) -> ServiceResource | None:
        if venue_id is None:
            venue = await self.get_default_venue()
            if venue is None:
                return None
            venue_id = venue.id

        number = court_number if court_number is not None else table_number
        if number is None or number <= 0:
            return None

        conditions = [
            ServiceResource.venue_id == _to_uuid(venue_id),
            ServiceResource.number == number,
            ServiceResource.status == ResourceStatus.ACTIVE,
        ]
        if court_type:
            resource_type = COURT_TYPE_TO_RESOURCE_TYPE.get(court_type)
            if resource_type:
                conditions.append(ServiceResource.resource_type == resource_type)

        stmt = select(ServiceResource).where(and_(*conditions)).limit(1)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_resource(
        self,
        *,
        venue_id: str,
        area_id: str | None,
        code: str,
        name: str,
        resource_type: str,
        sport_type: str | None,
        number: int,
        capacity: int | None,
        status: str,
        metadata: dict,
    ) -> ServiceResource:
        resource = ServiceResource(
            id=uuid.uuid4(),
            venue_id=_to_uuid(venue_id),
            area_id=_to_uuid(area_id) if area_id else None,
            code=code,
            name=name,
            resource_type=ResourceType(resource_type),
            sport_type=sport_type.lower() if sport_type else None,
            number=number,
            capacity=capacity,
            status=ResourceStatus(status),
            resource_metadata=metadata,
        )
        self._session.add(resource)
        await self._session.flush()
        return resource

    async def get_staff_access(self, staff_id: str) -> "StaffAccess":
        now = datetime.now(timezone.utc)
        stmt = select(StaffAssignment).where(
            StaffAssignment.staff_id == staff_id,
            StaffAssignment.is_active.is_(True),
            or_(StaffAssignment.starts_at.is_(None), StaffAssignment.starts_at <= now),
            or_(StaffAssignment.ends_at.is_(None), StaffAssignment.ends_at > now),
        )
        result = await self._session.execute(stmt)
        assignments = list(result.scalars().all())
        return StaffAccess.from_assignments(assignments)

    async def expand_accessible_resource_ids(
        self,
        access: "StaffAccess",
    ) -> set[uuid.UUID]:
        resource_ids = set(access.resource_ids)
        if access.area_ids:
            stmt = select(ServiceResource.id).where(
                ServiceResource.area_id.in_(list(access.area_ids))
            )
            result = await self._session.execute(stmt)
            resource_ids.update(result.scalars().all())
        return resource_ids

    async def list_staff_assignments(
        self,
        staff_id: str | None = None,
    ) -> list[StaffAssignment]:
        stmt = select(StaffAssignment).order_by(StaffAssignment.created_at.desc())
        if staff_id:
            stmt = stmt.where(StaffAssignment.staff_id == staff_id)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def create_staff_assignment(
        self,
        *,
        staff_id: str,
        venue_id: str,
        area_id: str | None,
        resource_id: str | None,
        scope: str,
        starts_at: datetime | None,
        ends_at: datetime | None,
    ) -> StaffAssignment:
        assignment = StaffAssignment(
            id=uuid.uuid4(),
            staff_id=staff_id,
            venue_id=_to_uuid(venue_id),
            area_id=_to_uuid(area_id) if area_id else None,
            resource_id=_to_uuid(resource_id) if resource_id else None,
            scope=StaffAssignmentScope(scope),
            starts_at=starts_at,
            ends_at=ends_at,
            is_active=True,
        )
        self._session.add(assignment)
        await self._session.flush()
        return assignment

    async def list_staff_ids_for_resource(
        self,
        *,
        venue_id: str | uuid.UUID | None,
        resource_id: str | uuid.UUID | None,
    ) -> list[str]:
        if venue_id is None and resource_id is None:
            return []

        resource = None
        resource_uuid = None
        if resource_id is not None:
            resource_uuid = _to_uuid(resource_id)
            resource = await self.get_resource_by_id(resource_uuid)
            if resource and venue_id is None:
                venue_id = resource.venue_id

        now = datetime.now(timezone.utc)
        conditions = [
            StaffAssignment.is_active.is_(True),
            or_(StaffAssignment.starts_at.is_(None), StaffAssignment.starts_at <= now),
            or_(StaffAssignment.ends_at.is_(None), StaffAssignment.ends_at > now),
        ]
        scope_conditions = []
        if venue_id is not None:
            scope_conditions.append(
                and_(
                    StaffAssignment.scope == StaffAssignmentScope.VENUE,
                    StaffAssignment.venue_id == _to_uuid(venue_id),
                )
            )
        if resource_uuid is not None:
            scope_conditions.append(
                and_(
                    StaffAssignment.scope == StaffAssignmentScope.RESOURCE,
                    StaffAssignment.resource_id == resource_uuid,
                )
            )
        if resource and resource.area_id:
            scope_conditions.append(
                and_(
                    StaffAssignment.scope == StaffAssignmentScope.AREA,
                    StaffAssignment.area_id == resource.area_id,
                )
            )

        if not scope_conditions:
            return []

        stmt = select(StaffAssignment.staff_id).where(
            and_(*conditions),
            or_(*scope_conditions),
        )
        result = await self._session.execute(stmt)
        return sorted(set(result.scalars().all()))


class StaffAccess:
    def __init__(
        self,
        *,
        venue_ids: set[uuid.UUID],
        venue_scope_ids: set[uuid.UUID],
        area_ids: set[uuid.UUID],
        resource_ids: set[uuid.UUID],
        has_assignments: bool,
    ) -> None:
        self.venue_ids = venue_ids
        self.venue_scope_ids = venue_scope_ids
        self.area_ids = area_ids
        self.resource_ids = resource_ids
        self.has_assignments = has_assignments

    @classmethod
    def from_assignments(cls, assignments: list[StaffAssignment]) -> "StaffAccess":
        venue_ids: set[uuid.UUID] = set()
        venue_scope_ids: set[uuid.UUID] = set()
        area_ids: set[uuid.UUID] = set()
        resource_ids: set[uuid.UUID] = set()
        for assignment in assignments:
            venue_ids.add(assignment.venue_id)
            if assignment.scope == StaffAssignmentScope.VENUE:
                venue_scope_ids.add(assignment.venue_id)
            if assignment.scope == StaffAssignmentScope.AREA and assignment.area_id:
                area_ids.add(assignment.area_id)
            if (
                assignment.scope == StaffAssignmentScope.RESOURCE
                and assignment.resource_id
            ):
                resource_ids.add(assignment.resource_id)
        return cls(
            venue_ids=venue_ids,
            venue_scope_ids=venue_scope_ids,
            area_ids=area_ids,
            resource_ids=resource_ids,
            has_assignments=bool(assignments),
        )


def _to_uuid(value: str | uuid.UUID) -> uuid.UUID:
    if isinstance(value, uuid.UUID):
        return value
    return uuid.UUID(str(value))
