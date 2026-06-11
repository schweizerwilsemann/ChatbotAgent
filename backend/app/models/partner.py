import enum
import uuid
from decimal import Decimal

from sqlalchemy import Boolean, Enum, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin


class PartnerStoreStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"
    suspended = "suspended"


class PartnerOrderStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    preparing = "preparing"
    ready = "ready"
    delivering = "delivering"
    delivered = "delivered"
    cancelled = "cancelled"


class PartnerStore(UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin, Base):
    __tablename__ = "partner_stores"

    owner_user_id: Mapped[str] = mapped_column(
        String(128), nullable=False, index=True
    )
    venue_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venues.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(
        String(64), default="food", index=True
    )  # food, drink, dessert, combo
    logo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[PartnerStoreStatus] = mapped_column(
        Enum(PartnerStoreStatus, name="partner_store_status_enum"),
        default=PartnerStoreStatus.active,
        nullable=False,
    )
    is_open: Mapped[bool] = mapped_column(Boolean, default=True)
    rating: Mapped[Decimal] = mapped_column(Numeric(3, 2), default=Decimal("5.00"))
    total_orders: Mapped[int] = mapped_column(Integer, default=0)
    delivery_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=Decimal("15000")
    )
    estimated_delivery_minutes: Mapped[int] = mapped_column(Integer, default=20)

    items: Mapped[list["PartnerMenuItem"]] = relationship(
        back_populates="store", cascade="all, delete-orphan"
    )
    orders: Mapped[list["PartnerOrder"]] = relationship(
        back_populates="store", cascade="all, delete-orphan"
    )


class PartnerMenuItem(UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin, Base):
    __tablename__ = "partner_menu_items"

    store_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("partner_stores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    category: Mapped[str] = mapped_column(
        String(64), default="food", index=True
    )  # food, drink, dessert, combo
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    sales_count: Mapped[int] = mapped_column(Integer, default=0)

    store: Mapped["PartnerStore"] = relationship(back_populates="items")


class PartnerOrder(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "partner_orders"

    store_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("partner_stores.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    customer_user_id: Mapped[str] = mapped_column(
        String(128), nullable=False, index=True
    )
    customer_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    customer_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    venue_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("venues.id", ondelete="SET NULL"),
        nullable=True,
    )
    delivery_location: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )  # e.g. "Bàn B03" or "Sân P02"
    status: Mapped[PartnerOrderStatus] = mapped_column(
        Enum(PartnerOrderStatus, name="partner_order_status_enum"),
        default=PartnerOrderStatus.pending,
        nullable=False,
    )
    payment_status: Mapped[str] = mapped_column(
        String(20), default="unpaid"
    )  # unpaid, paid
    subtotal: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=Decimal("0")
    )
    delivery_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=Decimal("15000")
    )
    total_price: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=Decimal("0")
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    store: Mapped["PartnerStore"] = relationship(back_populates="orders")
    items: Mapped[list["PartnerOrderItem"]] = relationship(
        back_populates="order", cascade="all, delete-orphan"
    )


class PartnerOrderItem(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "partner_order_items"

    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("partner_orders.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    item_name: Mapped[str] = mapped_column(String(255), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    order: Mapped["PartnerOrder"] = relationship(back_populates="items")
