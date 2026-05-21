import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class StaffRequest(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "staff_requests"

    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    user_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    venue_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venues.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    resource_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("service_resources.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    resource_label: Mapped[str | None] = mapped_column(String(255), nullable=True)
    request_type: Mapped[str] = mapped_column(
        Enum(
            "order",
            "payment",
            "help",
            "maintenance",
            "other",
            name="staff_request_type_enum",
        ),
        nullable=False,
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    table_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(
        Enum(
            "pending",
            "accepted",
            "completed",
            "cancelled",
            name="staff_request_status_enum",
        ),
        nullable=False,
        server_default="pending",
    )
    accepted_by: Mapped[str | None] = mapped_column(
        String(128), nullable=True, index=True
    )
    accepted_by_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
