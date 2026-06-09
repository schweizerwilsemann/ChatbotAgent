import enum
import uuid

from sqlalchemy import Boolean, Enum, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin


class CameraBrand(str, enum.Enum):
    HIK = "hik"
    DAHUA = "dahua"
    SEETONG = "seetong"
    FPT = "fpt"
    CUSTOM = "custom"


class Camera(UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin, Base):
    __tablename__ = "cameras"

    venue_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venues.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    resource_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("service_resources.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    ip_address: Mapped[str] = mapped_column(String(45), nullable=False)
    port: Mapped[int] = mapped_column(Integer, nullable=False, default=554)
    username: Mapped[str] = mapped_column(String(128), nullable=False, default="admin")
    password: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    camera_brand: Mapped[CameraBrand] = mapped_column(
        Enum(CameraBrand, name="camera_brand_enum"),
        nullable=False,
        default=CameraBrand.CUSTOM,
    )
    rtsp_url_override: Mapped[str | None] = mapped_column(
        String(1024), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
