import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class Order(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "orders"

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
    table_number: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
    status: Mapped[str] = mapped_column(
        Enum(
            "pending",
            "preparing",
            "ready",
            "delivered",
            "cancelled",
            name="order_status_enum",
        ),
        nullable=False,
        server_default="pending",
    )
    payment_status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        server_default="unpaid",
    )
    total_price: Mapped[Decimal] = mapped_column(
        Numeric(precision=12, scale=2), nullable=False, server_default="0"
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    items: Mapped[list["OrderItem"]] = relationship(
        back_populates="order", cascade="all, delete-orphan"
    )


class OrderItem(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "order_items"

    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False
    )
    item_name: Mapped[str] = mapped_column(String(255), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, server_default="1")
    unit_price: Mapped[Decimal] = mapped_column(
        Numeric(precision=12, scale=2), nullable=False
    )

    order: Mapped["Order"] = relationship(back_populates="items")
