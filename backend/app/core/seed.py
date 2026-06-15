import logging
from decimal import Decimal

from app.repositories.menu_repository import MenuRepository
from app.core.security import hash_password, verify_password
from app.models.menu import MenuItem
from app.models.user import User, UserRole
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
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

logger = logging.getLogger(__name__)

DEFAULT_PASSWORD = "123456"

CUSTOMER_PHONE = "0900000000"

ADMIN_BIDA_PHONE = "0111111111"
STAFF_BIDA_PHONE = "0111111112"
ADMIN_PICKLEBALL_PHONE = "0222222222"
STAFF_PICKLEBALL_PHONE = "0222222223"
ADMIN_CAULONG_PHONE = "0333333333"
STAFF_CAULONG_PHONE = "0333333334"

DEFAULT_BUSINESS_SLUG = "default-sports-venue"

DEFAULT_MENU_ITEMS = [
    {
        "name": "Cà phê đen",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Cà phê đậm, hợp khi chơi buổi chiều hoặc tối",
        "unit": "VND/ly",
        "price": Decimal("25000"),
        "tags": "cafe, caffeine, ít ngọt, đậm",
        "sales_count": 120,
    },
    {
        "name": "Cà phê sữa",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Cà phê sữa vị ngọt vừa, dễ uống",
        "unit": "VND/ly",
        "price": Decimal("30000"),
        "tags": "cafe, ngọt, sữa, bán chạy",
        "sales_count": 150,
    },
    {
        "name": "Trà đá",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Trà đá mát, nhẹ và dễ uống khi chơi lâu",
        "unit": "VND/ly",
        "price": Decimal("10000"),
        "tags": "mát, ít ngọt, giải khát",
        "sales_count": 180,
    },
    {
        "name": "Nước cam",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Nước cam tươi, vị chua ngọt",
        "unit": "VND/ly",
        "price": Decimal("35000"),
        "tags": "trái cây, chua ngọt, vitamin, mát",
        "sales_count": 90,
    },
    {
        "name": "Coca Cola",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Nước ngọt có gas",
        "unit": "VND/lon",
        "price": Decimal("20000"),
        "tags": "nước ngọt, có gas, lạnh",
        "sales_count": 130,
    },
    {
        "name": "Pepsi",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Nước ngọt có gas",
        "unit": "VND/lon",
        "price": Decimal("20000"),
        "tags": "nước ngọt, có gas, lạnh",
        "sales_count": 105,
    },
    {
        "name": "Bia Heineken",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Bia lon lạnh",
        "unit": "VND/lon",
        "price": Decimal("35000"),
        "tags": "bia, lạnh, người lớn",
        "sales_count": 95,
    },
    {
        "name": "Bia Tiger",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Bia lon lạnh",
        "unit": "VND/lon",
        "price": Decimal("30000"),
        "tags": "bia, lạnh, người lớn",
        "sales_count": 88,
    },
    {
        "name": "Nước suối",
        "category_key": "drinks",
        "category_name": "Đồ uống",
        "description": "Nước suối đóng chai",
        "unit": "VND/chai",
        "price": Decimal("10000"),
        "tags": "nước, không đường, lành mạnh",
        "sales_count": 170,
    },
    {
        "name": "Khô bò",
        "category_key": "snacks",
        "category_name": "Đồ ăn",
        "description": "Món nhắm cay nhẹ, hợp đi nhóm",
        "unit": "VND/phần",
        "price": Decimal("50000"),
        "tags": "ăn vặt, cay, món nhắm, bán chạy",
        "sales_count": 145,
    },
    {
        "name": "Khô gà",
        "category_key": "snacks",
        "category_name": "Đồ ăn",
        "description": "Khô gà lá chanh, cay nhẹ",
        "unit": "VND/phần",
        "price": Decimal("45000"),
        "tags": "ăn vặt, cay nhẹ, gà",
        "sales_count": 118,
    },
    {
        "name": "Mực nướng",
        "category_key": "snacks",
        "category_name": "Đồ ăn",
        "description": "Mực nướng xé, hợp dùng chung",
        "unit": "VND/phần",
        "price": Decimal("60000"),
        "tags": "món nhắm, hải sản, nhóm",
        "sales_count": 75,
    },
    {
        "name": "Khoai tây chiên",
        "category_key": "snacks",
        "category_name": "Đồ ăn",
        "description": "Khoai chiên giòn, dễ ăn",
        "unit": "VND/phần",
        "price": Decimal("40000"),
        "tags": "ăn vặt, không cay, trẻ em, giòn",
        "sales_count": 155,
    },
    {
        "name": "Đậu phộng rang",
        "category_key": "snacks",
        "category_name": "Đồ ăn",
        "description": "Đậu phộng rang muối",
        "unit": "VND/phần",
        "price": Decimal("25000"),
        "tags": "món nhắm, rẻ, ăn vặt",
        "sales_count": 135,
    },
    {
        "name": "Xúc xích nướng",
        "category_key": "snacks",
        "category_name": "Đồ ăn",
        "description": "Xúc xích nướng nóng",
        "unit": "VND/phần",
        "price": Decimal("35000"),
        "tags": "ăn nhanh, nóng, không cay",
        "sales_count": 110,
    },
    {
        "name": "Bánh tráng trộn",
        "category_key": "snacks",
        "category_name": "Đồ ăn",
        "description": "Bánh tráng trộn vị chua cay",
        "unit": "VND/phần",
        "price": Decimal("30000"),
        "tags": "ăn vặt, chua cay",
        "sales_count": 125,
    },
]

BILLIARDS_MENU_ITEMS = [
    {
        "name": "Bida lỗ (1 giờ)",
        "category_key": "services",
        "category_name": "Dịch vụ",
        "description": "Giá chơi bida lỗ theo giờ",
        "unit": "VND/giờ",
        "price": Decimal("50000"),
        "tags": "bida, sân, dịch vụ",
        "sales_count": 0,
    },
    {
        "name": "Bida phăng (1 giờ)",
        "category_key": "services",
        "category_name": "Dịch vụ",
        "description": "Giá chơi bida phăng theo giờ",
        "unit": "VND/giờ",
        "price": Decimal("40000"),
        "tags": "bida, sân, dịch vụ",
        "sales_count": 0,
    },
    {
        "name": "Gậy cơ cho thuê",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Gậy cơ tiêu chuẩn cho khách thuê",
        "unit": "VND/cây",
        "price": Decimal("20000"),
        "tags": "bida, cơ, thuê",
        "sales_count": 0,
    },
    {
        "name": "Gậy cơ cao cấp",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Gậy cơ chuyên nghiệp, đầu ngà",
        "unit": "VND/cây",
        "price": Decimal("50000"),
        "tags": "bida, cơ, cao cấp, thuê",
        "sales_count": 0,
    },
    {
        "name": "Găng tay chơi bida",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Găng tay chống trượt, thoáng khí",
        "unit": "VND/chiếc",
        "price": Decimal("30000"),
        "tags": "bida, găng tay, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Phấn bida",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Phấn Blue chalk, chống trượt đầu cơ",
        "unit": "VND/viên",
        "price": Decimal("10000"),
        "tags": "bida, phấn, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Đầu cơ thay thế",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Đầu cơ Le Pro, mềm, bám phấn tốt",
        "unit": "VND/cái",
        "price": Decimal("25000"),
        "tags": "bida, đầu cơ, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Giá để cơ",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Giá gỗ 6 lỗ, để cơ gọn gàng",
        "unit": "VND/lần sử dụng",
        "price": Decimal("10000"),
        "tags": "bida, giá, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Bàn chải mặt bàn",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Bàn chải chuyên dụng vệ sinh mặt nỉ",
        "unit": "VND/lần",
        "price": Decimal("5000"),
        "tags": "bida, bàn chải, vệ sinh",
        "sales_count": 0,
    },
    {
        "name": "Triangle xếp bóng",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Khung xếp bóng hình tam giác",
        "unit": "VND/lần",
        "price": Decimal("5000"),
        "tags": "bida, triangle, phụ kiện",
        "sales_count": 0,
    },
]

PICKLEBALL_MENU_ITEMS = [
    {
        "name": "Sân pickleball (1 giờ)",
        "category_key": "services",
        "category_name": "Dịch vụ",
        "description": "Giá thuê sân pickleball theo giờ",
        "unit": "VND/giờ",
        "price": Decimal("80000"),
        "tags": "pickleball, sân, dịch vụ",
        "sales_count": 0,
    },
    {
        "name": "Vợt cho thuê",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Vợt pickleball cơ bản, phù hợp mọi trình độ",
        "unit": "VND/cây",
        "price": Decimal("30000"),
        "tags": "pickleball, vợt, thuê",
        "sales_count": 0,
    },
    {
        "name": "Vợt cao cấp cho thuê",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Vợt carbon fiber, nhẹ, kiểm soát tốt",
        "unit": "VND/cây",
        "price": Decimal("60000"),
        "tags": "pickleball, vợt, cao cấp, thuê",
        "sales_count": 0,
    },
    {
        "name": "Ống bóng (3 quả)",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Bóng pickleball Dura chính hãng",
        "unit": "VND/ống",
        "price": Decimal("50000"),
        "tags": "pickleball, bóng, thuê",
        "sales_count": 0,
    },
    {
        "name": "Ống bóng (12 quả)",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Bóng pickleball Dura, hộp lớn",
        "unit": "VND/ống",
        "price": Decimal("180000"),
        "tags": "pickleball, bóng, thuê, hộp lớn",
        "sales_count": 0,
    },
    {
        "name": "Quấn cán vợt",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Quấn cán chống trượt, thấm mồ hôi",
        "unit": "VND/cuộn",
        "price": Decimal("15000"),
        "tags": "pickleball, quấn cán, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Balo đựng vợt",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Balo chuyên dụng, đựng 2 vợt + bóng",
        "unit": "VND/cái",
        "price": Decimal("150000"),
        "tags": "pickleball, balo, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Dây đeo vợt",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Dây đeo vợt chống rơi",
        "unit": "VND/sợi",
        "price": Decimal("20000"),
        "tags": "pickleball, dây đeo, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Phấn chống trượt",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Phấn khô chống trượt tay",
        "unit": "VND/hộp",
        "price": Decimal("25000"),
        "tags": "pickleball, phấn, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Kính mắt thể thao",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Kính chống UV, chống va đập",
        "unit": "VND/cái",
        "price": Decimal("80000"),
        "tags": "pickleball, kính, phụ kiện",
        "sales_count": 0,
    },
]

BADMINTON_MENU_ITEMS = [
    {
        "name": "Sân cầu lông (1 giờ)",
        "category_key": "services",
        "category_name": "Dịch vụ",
        "description": "Giá thuê sân cầu lông theo giờ",
        "unit": "VND/giờ",
        "price": Decimal("100000"),
        "tags": "cầu lông, sân, dịch vụ",
        "sales_count": 0,
    },
    {
        "name": "Vợt cho thuê",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Vợt cầu lông cơ bản, phù hợp mọi trình độ",
        "unit": "VND/cây",
        "price": Decimal("30000"),
        "tags": "cầu lông, vợt, thuê",
        "sales_count": 0,
    },
    {
        "name": "Vợt cao cấp cho thuê",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Vợt Yonex/Victor, carbon, chuyên nghiệp",
        "unit": "VND/cây",
        "price": Decimal("60000"),
        "tags": "cầu lông, vợt, cao cấp, thuê",
        "sales_count": 0,
    },
    {
        "name": "Ống cầu (12 quả)",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Cầu lông thi đấu, lông ngỗng",
        "unit": "VND/ống",
        "price": Decimal("120000"),
        "tags": "cầu lông, cầu, thuê",
        "sales_count": 0,
    },
    {
        "name": "Ống cầu tập luyện",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Cầu lông tập luyện, lông nhựa",
        "unit": "VND/ống",
        "price": Decimal("60000"),
        "tags": "cầu lông, cầu, tập luyện, thuê",
        "sales_count": 0,
    },
    {
        "name": "Cước vợt",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Cước đan vợt BG65, bền, kiểm soát tốt",
        "unit": "VND/sợi",
        "price": Decimal("50000"),
        "tags": "cầu lông, cước, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Quấn cán vợt",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Quấn cán Yonex, chống trượt, thấm mồ hôi",
        "unit": "VND/cuộn",
        "price": Decimal("20000"),
        "tags": "cầu lông, quấn cán, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Túi đựng vợt",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Túi đựng 2-3 vợt, có ngăn giày",
        "unit": "VND/cái",
        "price": Decimal("200000"),
        "tags": "cầu lông, túi, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Băng cổ tay",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Băng cổ tay thấm mồ hôi",
        "unit": "VND/đôi",
        "price": Decimal("25000"),
        "tags": "cầu lông, băng tay, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Băng đầu gối",
        "category_key": "accessories",
        "category_name": "Phụ kiện",
        "description": "Băng bảo vệ đầu gối, co giãn tốt",
        "unit": "VND/đôi",
        "price": Decimal("40000"),
        "tags": "cầu lông, băng gối, phụ kiện",
        "sales_count": 0,
    },
    {
        "name": "Giày cầu lông",
        "category_key": "rental",
        "category_name": "Cho thuê",
        "description": "Giày chuyên dụng, bám sân, chống trượt",
        "unit": "VND/đôi",
        "price": Decimal("40000"),
        "tags": "cầu lông, giày, thuê",
        "sales_count": 0,
    },
]


async def ensure_user_password_column(engine: AsyncEngine) -> None:
    async with engine.begin() as conn:
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)")
        )


async def ensure_multi_tenant_columns(engine: AsyncEngine) -> None:
    async with engine.begin() as conn:
        statements = [
            "ALTER TYPE user_role_enum ADD VALUE IF NOT EXISTS 'PARTNER'",
            "ALTER TYPE booking_status_enum ADD VALUE IF NOT EXISTS 'checked_in'",
            "ALTER TYPE staff_request_type_enum ADD VALUE IF NOT EXISTS 'early_arrival'",
            "ALTER TYPE staff_request_type_enum ADD VALUE IF NOT EXISTS 'late_arrival'",
            "ALTER TYPE staff_request_type_enum ADD VALUE IF NOT EXISTS 'schedule_change'",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS business_id UUID",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS default_venue_id UUID",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255)",
            "CREATE INDEX IF NOT EXISTS ix_users_business_id ON users (business_id)",
            "CREATE INDEX IF NOT EXISTS ix_users_default_venue_id ON users (default_venue_id)",
            "CREATE INDEX IF NOT EXISTS ix_users_stripe_customer_id ON users (stripe_customer_id)",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS venue_id UUID",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS resource_id UUID",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS resource_label VARCHAR(255)",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) NOT NULL DEFAULT 'unpaid'",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS checkin_token VARCHAR(128)",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS checked_in_by VARCHAR(128)",
            "CREATE INDEX IF NOT EXISTS ix_bookings_venue_id ON bookings (venue_id)",
            "CREATE INDEX IF NOT EXISTS ix_bookings_resource_id ON bookings (resource_id)",
            "CREATE UNIQUE INDEX IF NOT EXISTS ix_bookings_checkin_token ON bookings (checkin_token)",
            "ALTER TABLE orders ADD COLUMN IF NOT EXISTS venue_id UUID",
            "ALTER TABLE orders ADD COLUMN IF NOT EXISTS booking_id UUID",
            "ALTER TABLE orders ADD COLUMN IF NOT EXISTS resource_id UUID",
            "ALTER TABLE orders ADD COLUMN IF NOT EXISTS resource_label VARCHAR(255)",
            "ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) NOT NULL DEFAULT 'unpaid'",
            "ALTER TABLE orders ADD COLUMN IF NOT EXISTS notes TEXT",
            "CREATE INDEX IF NOT EXISTS ix_orders_venue_id ON orders (venue_id)",
            "CREATE INDEX IF NOT EXISTS ix_orders_booking_id ON orders (booking_id)",
            "CREATE INDEX IF NOT EXISTS ix_orders_resource_id ON orders (resource_id)",
            "ALTER TABLE staff_requests ADD COLUMN IF NOT EXISTS venue_id UUID",
            "ALTER TABLE staff_requests ADD COLUMN IF NOT EXISTS resource_id UUID",
            "ALTER TABLE staff_requests ADD COLUMN IF NOT EXISTS resource_label VARCHAR(255)",
            "CREATE INDEX IF NOT EXISTS ix_staff_requests_venue_id ON staff_requests (venue_id)",
            "CREATE INDEX IF NOT EXISTS ix_staff_requests_resource_id ON staff_requests (resource_id)",
            "ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS venue_id UUID",
            "CREATE INDEX IF NOT EXISTS ix_menu_items_venue_id ON menu_items (venue_id)",
            "ALTER TABLE menu_items DROP CONSTRAINT IF EXISTS menu_items_name_key",
            # Soft delete columns
            "ALTER TABLE venues ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE",
            "ALTER TABLE venues ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ",
            "CREATE INDEX IF NOT EXISTS ix_venues_is_deleted ON venues (is_deleted)",
            "ALTER TABLE service_resources ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE",
            "ALTER TABLE service_resources ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ",
            "CREATE INDEX IF NOT EXISTS ix_service_resources_is_deleted ON service_resources (is_deleted)",
            "ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE",
            "ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ",
            "CREATE INDEX IF NOT EXISTS ix_menu_items_is_deleted ON menu_items (is_deleted)",
            # Pricing columns
            "ALTER TABLE service_resources ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC(12, 2) DEFAULT NULL",
            "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS total_price NUMERIC(12, 2) DEFAULT NULL",
            # Seed default pricing for existing resources
            "UPDATE service_resources SET hourly_rate = 80000  WHERE sport_type = 'billiards'  AND hourly_rate IS NULL",
            "UPDATE service_resources SET hourly_rate = 120000 WHERE sport_type = 'pickleball' AND hourly_rate IS NULL",
            "UPDATE service_resources SET hourly_rate = 100000 WHERE sport_type = 'badminton'  AND hourly_rate IS NULL",
            # Cameras table
            """CREATE TABLE IF NOT EXISTS cameras (
                id UUID PRIMARY KEY,
                venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
                resource_id UUID REFERENCES service_resources(id) ON DELETE SET NULL,
                name VARCHAR(255) NOT NULL,
                ip_address VARCHAR(45) NOT NULL,
                port INTEGER NOT NULL DEFAULT 554,
                username VARCHAR(128) NOT NULL DEFAULT 'admin',
                password VARCHAR(255) NOT NULL DEFAULT '',
                camera_brand VARCHAR(20) NOT NULL DEFAULT 'custom',
                rtsp_url_override VARCHAR(1024),
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
                deleted_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )""",
            "CREATE INDEX IF NOT EXISTS ix_cameras_venue_id ON cameras (venue_id)",
            "CREATE INDEX IF NOT EXISTS ix_cameras_resource_id ON cameras (resource_id)",
            "CREATE INDEX IF NOT EXISTS ix_cameras_is_deleted ON cameras (is_deleted)",
        ]
        for statement in statements:
            await conn.execute(text(statement))


async def _ensure_user(
    session: AsyncSession,
    *,
    phone: str,
    name: str,
    role: UserRole,
    business: Business | None = None,
    venue: Venue | None = None,
) -> User:
    result = await session.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            phone=phone,
            name=name,
            role=role,
            password_hash=hash_password(DEFAULT_PASSWORD),
        )
        session.add(user)
        await session.flush()

    user.name = name
    user.role = role
    if not verify_password(DEFAULT_PASSWORD, user.password_hash):
        user.password_hash = hash_password(DEFAULT_PASSWORD)
    if business:
        user.business_id = business.id
    if venue:
        user.default_venue_id = venue.id
    await session.flush()
    return user


async def seed_customer_user(session: AsyncSession) -> User:
    return await _ensure_user(
        session,
        phone=CUSTOMER_PHONE,
        name="Khách hàng",
        role=UserRole.CUSTOMER,
    )


async def seed_admin_user(session: AsyncSession) -> User:
    return await _ensure_user(
        session,
        phone="0123456789",
        name="Quản lý",
        role=UserRole.ADMIN,
    )


async def seed_staff_user(session: AsyncSession) -> User:
    return await _ensure_user(
        session,
        phone="0987654321",
        name="Nhân viên",
        role=UserRole.STAFF,
    )


async def seed_default_venue(
    session: AsyncSession,
    *,
    customer_user: User,
) -> tuple[Venue, Venue, Venue]:
    from datetime import datetime, timezone

    result = await session.execute(
        select(Business).where(Business.slug == DEFAULT_BUSINESS_SLUG)
    )
    business = result.scalar_one_or_none()
    if business is None:
        business = Business(
            name="Sports Venue Demo",
            slug=DEFAULT_BUSINESS_SLUG,
            owner_user_id=str(customer_user.id),
            is_active=True,
        )
        session.add(business)
        await session.flush()

    # Soft delete old venues not in the new list
    new_venue_names = {
        "CLB Bida Sài Gòn",
        "Sân Pickleball Thủ Đức",
        "Nhà thi đấu Cầu lông Bình Thạnh",
    }
    old_venues = await session.execute(
        select(Venue).where(
            Venue.business_id == business.id,
            Venue.is_deleted.is_(False),
            Venue.name.notin_(new_venue_names),
        )
    )
    now = datetime.now(timezone.utc)
    for old_venue in old_venues.scalars().all():
        old_venue.is_deleted = True
        old_venue.deleted_at = now
        # Cascade soft delete to child resources
        resources = await session.execute(
            select(ServiceResource).where(
                ServiceResource.venue_id == old_venue.id,
                ServiceResource.is_deleted.is_(False),
            )
        )
        for res in resources.scalars().all():
            res.is_deleted = True
            res.deleted_at = now
    await session.flush()

    billiards_venue = await _seed_billiards_venue(session, business)
    pickleball_venue = await _seed_pickleball_venue(session, business)
    badminton_venue = await _seed_badminton_venue(session, business)

    admin_bida = await _ensure_user(
        session,
        phone=ADMIN_BIDA_PHONE,
        name="Quản lý Bida",
        role=UserRole.ADMIN,
        business=business,
        venue=billiards_venue,
    )
    staff_bida = await _ensure_user(
        session,
        phone=STAFF_BIDA_PHONE,
        name="NV Bida",
        role=UserRole.STAFF,
        business=business,
        venue=billiards_venue,
    )

    admin_pickleball = await _ensure_user(
        session,
        phone=ADMIN_PICKLEBALL_PHONE,
        name="Quản lý Pickleball",
        role=UserRole.ADMIN,
        business=business,
        venue=pickleball_venue,
    )
    staff_pickleball = await _ensure_user(
        session,
        phone=STAFF_PICKLEBALL_PHONE,
        name="NV Pickleball",
        role=UserRole.STAFF,
        business=business,
        venue=pickleball_venue,
    )

    admin_caulong = await _ensure_user(
        session,
        phone=ADMIN_CAULONG_PHONE,
        name="Quản lý Cầu lông",
        role=UserRole.ADMIN,
        business=business,
        venue=badminton_venue,
    )
    staff_caulong = await _ensure_user(
        session,
        phone=STAFF_CAULONG_PHONE,
        name="NV Cầu lông",
        role=UserRole.STAFF,
        business=business,
        venue=badminton_venue,
    )

    customer_user.business_id = business.id
    customer_user.default_venue_id = billiards_venue.id
    await session.flush()

    await _ensure_staff_venue_assignment(session, staff_bida, billiards_venue)
    await _ensure_staff_venue_assignment(session, staff_pickleball, pickleball_venue)
    await _ensure_staff_venue_assignment(session, staff_caulong, badminton_venue)

    await session.flush()
    logger.info("All venues seeded: bida=%s, pickleball=%s, cầu lông=%s",
                billiards_venue.name, pickleball_venue.name, badminton_venue.name)
    return billiards_venue, pickleball_venue, badminton_venue


async def _seed_billiards_venue(
    session: AsyncSession,
    business: Business,
) -> Venue:
    result = await session.execute(
        select(Venue).where(
            Venue.business_id == business.id,
            Venue.name == "CLB Bida Sài Gòn",
        )
    )
    venue = result.scalar_one_or_none()
    if venue is None:
        venue = Venue(
            business_id=business.id,
            name="CLB Bida Sài Gòn",
            address="123 Nguyễn Huệ, Q.1, TP.HCM",
            timezone="Asia/Ho_Chi_Minh",
            is_active=True,
        )
        session.add(venue)
        await session.flush()

    area = await _ensure_area(session, venue, "Khu chơi bida", 1)

    for number in range(1, 9):
        await _ensure_resource(
            session,
            venue=venue,
            area=area,
            code=f"B{number:02d}",
            name=f"Bàn bida {number}",
            resource_type=ResourceType.BILLIARDS_TABLE,
            sport_type="billiards",
            number=number,
            capacity=4,
            hourly_rate=80000,
        )

    logger.info("Seeded billiards venue: %s (8 bàn)", venue.name)
    return venue


async def _seed_pickleball_venue(
    session: AsyncSession,
    business: Business,
) -> Venue:
    result = await session.execute(
        select(Venue).where(
            Venue.business_id == business.id,
            Venue.name == "Sân Pickleball Thủ Đức",
        )
    )
    venue = result.scalar_one_or_none()
    if venue is None:
        venue = Venue(
            business_id=business.id,
            name="Sân Pickleball Thủ Đức",
            address="456 Võ Văn Ngân, Thủ Đức, TP.HCM",
            timezone="Asia/Ho_Chi_Minh",
            is_active=True,
        )
        session.add(venue)
        await session.flush()

    area = await _ensure_area(session, venue, "Sân pickleball", 1)

    for number in range(1, 7):
        await _ensure_resource(
            session,
            venue=venue,
            area=area,
            code=f"P{number:02d}",
            name=f"Sân pickleball {number}",
            resource_type=ResourceType.PICKLEBALL_COURT,
            sport_type="pickleball",
            number=number,
            capacity=4,
            hourly_rate=120000,
        )

    logger.info("Seeded pickleball venue: %s (6 sân)", venue.name)
    return venue


async def _seed_badminton_venue(
    session: AsyncSession,
    business: Business,
) -> Venue:
    result = await session.execute(
        select(Venue).where(
            Venue.business_id == business.id,
            Venue.name == "Nhà thi đấu Cầu lông Bình Thạnh",
        )
    )
    venue = result.scalar_one_or_none()
    if venue is None:
        venue = Venue(
            business_id=business.id,
            name="Nhà thi đấu Cầu lông Bình Thạnh",
            address="789 Xô Viết Nghệ Tĩnh, Bình Thạnh, TP.HCM",
            timezone="Asia/Ho_Chi_Minh",
            is_active=True,
        )
        session.add(venue)
        await session.flush()

    area = await _ensure_area(session, venue, "Sân cầu lông", 1)

    for number in range(1, 7):
        await _ensure_resource(
            session,
            venue=venue,
            area=area,
            code=f"C{number:02d}",
            name=f"Sân cầu lông {number}",
            resource_type=ResourceType.BADMINTON_COURT,
            sport_type="badminton",
            number=number,
            capacity=4,
            hourly_rate=100000,
        )

    logger.info("Seeded badminton venue: %s (6 sân)", venue.name)
    return venue


async def _ensure_area(
    session: AsyncSession,
    venue: Venue,
    name: str,
    sort_order: int,
) -> VenueArea:
    result = await session.execute(
        select(VenueArea).where(VenueArea.venue_id == venue.id, VenueArea.name == name)
    )
    area = result.scalar_one_or_none()
    if area is None:
        area = VenueArea(venue_id=venue.id, name=name, sort_order=sort_order)
        session.add(area)
        await session.flush()
    return area


async def _ensure_resource(
    session: AsyncSession,
    *,
    venue: Venue,
    area: VenueArea,
    code: str,
    name: str,
    resource_type: ResourceType,
    sport_type: str,
    number: int,
    capacity: int,
    hourly_rate=None,
) -> ServiceResource:
    result = await session.execute(
        select(ServiceResource).where(
            ServiceResource.venue_id == venue.id,
            ServiceResource.code == code,
        )
    )
    resource = result.scalar_one_or_none()
    if resource is None:
        resource = ServiceResource(
            venue_id=venue.id,
            area_id=area.id,
            code=code,
            name=name,
            resource_type=resource_type,
            sport_type=sport_type,
            number=number,
            capacity=capacity,
            status=ResourceStatus.ACTIVE,
            resource_metadata={},
            hourly_rate=hourly_rate,
        )
        session.add(resource)
    else:
        resource.name = name
        resource.area_id = area.id
        resource.resource_type = resource_type
        resource.sport_type = sport_type
        resource.number = number
        resource.capacity = capacity
        if hourly_rate is not None:
            resource.hourly_rate = hourly_rate
    await session.flush()
    return resource


async def _ensure_staff_venue_assignment(
    session: AsyncSession,
    staff_user: User,
    venue: Venue,
) -> StaffAssignment:
    result = await session.execute(
        select(StaffAssignment).where(
            StaffAssignment.staff_id == str(staff_user.id),
            StaffAssignment.venue_id == venue.id,
            StaffAssignment.scope == StaffAssignmentScope.VENUE,
            StaffAssignment.is_active.is_(True),
        )
    )
    assignment = result.scalar_one_or_none()
    if assignment is None:
        assignment = StaffAssignment(
            staff_id=str(staff_user.id),
            venue_id=venue.id,
            scope=StaffAssignmentScope.VENUE,
            is_active=True,
        )
        session.add(assignment)
        await session.flush()
    return assignment


async def seed_default_menu(
    session: AsyncSession,
    *,
    billiards_venue: Venue | None = None,
    pickleball_venue: Venue | None = None,
    badminton_venue: Venue | None = None,
) -> None:
    from datetime import datetime, timezone

    # Soft delete old menu items without venue_id (from previous seed)
    old_items = await session.execute(
        select(MenuItem).where(
            MenuItem.venue_id.is_(None),
            MenuItem.is_deleted.is_(False),
        )
    )
    now = datetime.now(timezone.utc)
    for item in old_items.scalars().all():
        item.is_deleted = True
        item.deleted_at = now
    await session.flush()

    # Clear menu cache in Redis
    try:
        from app.core.redis_client import redis_client
        cache_keys = await redis_client.keys("menu:*")
        if cache_keys:
            await redis_client.delete(*cache_keys)
    except Exception:
        pass

    repo = MenuRepository(session)
    for item in DEFAULT_MENU_ITEMS:
        await repo.upsert_seed_item(**item)

    if billiards_venue:
        for item in BILLIARDS_MENU_ITEMS:
            await repo.upsert_seed_item(venue_id=billiards_venue.id, **item)
    if pickleball_venue:
        for item in PICKLEBALL_MENU_ITEMS:
            await repo.upsert_seed_item(venue_id=pickleball_venue.id, **item)
    if badminton_venue:
        for item in BADMINTON_MENU_ITEMS:
            await repo.upsert_seed_item(venue_id=badminton_venue.id, **item)

    total = len(DEFAULT_MENU_ITEMS)
    if billiards_venue:
        total += len(BILLIARDS_MENU_ITEMS)
    if pickleball_venue:
        total += len(PICKLEBALL_MENU_ITEMS)
    if badminton_venue:
        total += len(BADMINTON_MENU_ITEMS)
    logger.info("Menu ensured: %d items", total)


# ── Partner Stores Seed ────────────────────────────────

PARTNER_PHONE_TRA_SUA = "0911111111"
PARTNER_PHONE_COM_GA = "0922222222"
PARTNER_PHONE_BANH_MI = "0933333333"

PARTNER_STORES = [
    {
        "phone": PARTNER_PHONE_TRA_SUA,
        "owner_name": "Chủ Trà Sữa Mèo",
        "store_name": "Trà Sữa Mèo",
        "description": "Trà sữa & đồ uống giải khát, giao tận sân",
        "category": "drink",
        "delivery_minutes": 15,
        "items": [
            {"name": "Trà Sữa Truyền Thống", "price": Decimal("28000"), "category": "drink", "description": "Trà sữa + trân châu đen"},
            {"name": "Trà Đào Cam Sả", "price": Decimal("32000"), "category": "drink", "description": "Trà đào thơm mát"},
            {"name": "Trà Vải", "price": Decimal("30000"), "category": "drink", "description": "Trà vải thiều lạnh"},
            {"name": "Sinh Tố Bơ", "price": Decimal("35000"), "category": "drink", "description": "Bơ sữa đặc sánh"},
            {"name": "Matcha Đá Xay", "price": Decimal("38000"), "category": "drink", "description": "Matcha Nhật kem tươi"},
            {"name": "Kem Vanilla", "price": Decimal("15000"), "category": "dessert", "description": "Kem vanilla mềm mịn"},
        ],
    },
    {
        "phone": PARTNER_PHONE_COM_GA,
        "owner_name": "Chủ Cơm Gà 123",
        "store_name": "Cơm Gà 123",
        "description": "Cơm gà, mì xào, đồ ăn nhanh giao tại sân",
        "category": "food",
        "delivery_minutes": 20,
        "items": [
            {"name": "Cơm Gà Chiên", "price": Decimal("45000"), "category": "food", "description": "Cơm + gà chiên giòn + salad"},
            {"name": "Cơm Sườn Nướng", "price": Decimal("50000"), "category": "food", "description": "Cơm + sườn nướng mật ong"},
            {"name": "Mì Xào Hải Sản", "price": Decimal("55000"), "category": "food", "description": "Mì xào tôm mực rau củ"},
            {"name": "Bánh Mì Thịt", "price": Decimal("25000"), "category": "food", "description": "Bánh mì pate thịt nguội"},
            {"name": "Coca Cola", "price": Decimal("15000"), "category": "drink", "description": "Lon 330ml"},
            {"name": "Nước Suối", "price": Decimal("10000"), "category": "drink", "description": "La Vie 500ml"},
        ],
    },
    {
        "phone": PARTNER_PHONE_BANH_MI,
        "owner_name": "Chủ Bánh Mì Ngon",
        "store_name": "Bánh Mì Ngon",
        "description": "Bánh mì & đồ ăn vặt, giá sinh viên",
        "category": "food",
        "delivery_minutes": 10,
        "items": [
            {"name": "Bánh Mì Pate", "price": Decimal("15000"), "category": "food", "description": "Bánh mì pate truyền thống"},
            {"name": "Bánh Mì Gà", "price": Decimal("20000"), "category": "food", "description": "Bánh mì gà xé phay"},
            {"name": "Xúc Xích Nướng", "price": Decimal("20000"), "category": "food", "description": "Xúc xích nướng than"},
            {"name": "Khoai Tây Chiên", "price": Decimal("25000"), "category": "food", "description": "Khoai giòn kèm sốt"},
            {"name": "Bánh Tráng Trộn", "price": Decimal("20000"), "category": "food", "description": "Bánh tráng sa tế"},
            {"name": "Trà Đá", "price": Decimal("5000"), "category": "drink", "description": "Trà đá mát lạnh"},
        ],
    },
]


async def seed_partner_stores(
    session: AsyncSession,
    *,
    billiards_venue: Venue | None = None,
) -> None:
    from app.models.partner import PartnerMenuItem as PMenuItem
    from app.models.partner import PartnerStore, PartnerStoreStatus

    venue = billiards_venue  # Default venue for partner stores

    for store_data in PARTNER_STORES:
        # Ensure partner user
        user = await _ensure_user(
            session,
            phone=store_data["phone"],
            name=store_data["owner_name"],
            role=UserRole.PARTNER,
        )

        # Check if store exists
        result = await session.execute(
            select(PartnerStore).where(
                PartnerStore.owner_user_id == str(user.id),
                PartnerStore.is_deleted == False,  # noqa: E712
            )
        )
        store = result.scalar_one_or_none()

        if store is None:
            store = PartnerStore(
                owner_user_id=str(user.id),
                venue_id=venue.id if venue else None,
                name=store_data["store_name"],
                description=store_data["description"],
                category=store_data["category"],
                status=PartnerStoreStatus.active,
                is_open=True,
                delivery_fee=Decimal("15000"),
                estimated_delivery_minutes=store_data["delivery_minutes"],
            )
            session.add(store)
            await session.flush()

        # Seed menu items
        for item_data in store_data["items"]:
            existing = await session.execute(
                select(PMenuItem).where(
                    PMenuItem.store_id == store.id,
                    PMenuItem.name == item_data["name"],
                    PMenuItem.is_deleted == False,  # noqa: E712
                )
            )
            if existing.scalar_one_or_none() is None:
                session.add(
                    PMenuItem(
                        store_id=store.id,
                        name=item_data["name"],
                        description=item_data.get("description", ""),
                        price=item_data["price"],
                        category=item_data["category"],
                        is_available=True,
                    )
                )

    await session.flush()
    logger.info("Partner stores ensured: %d stores", len(PARTNER_STORES))
