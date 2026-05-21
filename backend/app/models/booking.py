import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class Booking(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "bookings"

    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
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
    court_type: Mapped[str] = mapped_column(
        Enum("billiards", "pickleball", "badminton", name="court_type_enum"),
        nullable=False,
    )
    court_number: Mapped[int] = mapped_column(Integer, nullable=False)
    start_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(
        Enum("confirmed", "cancelled", "completed", name="booking_status_enum"),
        nullable=False,
        server_default="confirmed",
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
