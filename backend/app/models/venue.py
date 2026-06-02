import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin


class ResourceType(str, enum.Enum):
    BILLIARDS_TABLE = "billiards_table"
    PICKLEBALL_COURT = "pickleball_court"
    BADMINTON_COURT = "badminton_court"
    DINING_TABLE = "dining_table"
    OTHER = "other"


class ResourceStatus(str, enum.Enum):
    ACTIVE = "active"
    MAINTENANCE = "maintenance"
    INACTIVE = "inactive"


class StaffAssignmentScope(str, enum.Enum):
    VENUE = "venue"
    AREA = "area"
    RESOURCE = "resource"


class Business(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "businesses"

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    owner_user_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Venue(UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin, Base):
    __tablename__ = "venues"

    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    timezone: Mapped[str] = mapped_column(
        String(80),
        nullable=False,
        default="Asia/Ho_Chi_Minh",
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class VenueArea(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "venue_areas"
    __table_args__ = (
        UniqueConstraint("venue_id", "name", name="uq_venue_areas_venue_name"),
    )

    venue_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venues.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)


class ServiceResource(UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin, Base):
    __tablename__ = "service_resources"
    __table_args__ = (
        UniqueConstraint("venue_id", "code", name="uq_service_resources_venue_code"),
        UniqueConstraint(
            "venue_id",
            "resource_type",
            "number",
            name="uq_service_resources_venue_type_number",
        ),
    )

    venue_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venues.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    area_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venue_areas.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    code: Mapped[str] = mapped_column(String(40), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    resource_type: Mapped[ResourceType] = mapped_column(
        Enum(ResourceType, name="resource_type_enum"),
        nullable=False,
        index=True,
    )
    sport_type: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    number: Mapped[int] = mapped_column(Integer, nullable=False)
    capacity: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[ResourceStatus] = mapped_column(
        Enum(ResourceStatus, name="resource_status_enum"),
        nullable=False,
        default=ResourceStatus.ACTIVE,
        index=True,
    )
    resource_metadata: Mapped[dict] = mapped_column(
        "metadata",
        JSONB,
        nullable=False,
        default=dict,
    )
    hourly_rate: Mapped[float | None] = mapped_column(
        Numeric(precision=12, scale=2),
        nullable=True,
        default=None,
    )


class StaffAssignment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "staff_assignments"

    staff_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    venue_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venues.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    area_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venue_areas.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    resource_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("service_resources.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    scope: Mapped[StaffAssignmentScope] = mapped_column(
        Enum(StaffAssignmentScope, name="staff_assignment_scope_enum"),
        nullable=False,
        default=StaffAssignmentScope.VENUE,
    )
    starts_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    ends_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
