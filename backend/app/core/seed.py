import logging
from decimal import Decimal

from app.repositories.menu_repository import MenuRepository
from app.core.security import hash_password, verify_password
from app.models.user import User, UserRole
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

logger = logging.getLogger(__name__)

ADMIN_PHONE = "0123456789"
ADMIN_PASSWORD = "123456"
STAFF_PHONE = "0987654321"
STAFF_PASSWORD = "123456"
CUSTOMER_PHONE = "0900000000"
CUSTOMER_PASSWORD = "123456"

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
    {
        "name": "Bida lỗ (1 giờ)",
        "category_key": "billiards",
        "category_name": "Phụ kiện",
        "description": "Giá chơi bida lỗ theo giờ",
        "unit": "VND/giờ",
        "price": Decimal("50000"),
        "tags": "bida, sân, dịch vụ",
        "sales_count": 0,
    },
    {
        "name": "Bida phăng (1 giờ)",
        "category_key": "billiards",
        "category_name": "Phụ kiện",
        "description": "Giá chơi bida phăng theo giờ",
        "unit": "VND/giờ",
        "price": Decimal("40000"),
        "tags": "bida, sân, dịch vụ",
        "sales_count": 0,
    },
    {
        "name": "Gậy cơ cho thuê",
        "category_key": "billiards",
        "category_name": "Phụ kiện",
        "description": "Gậy cơ cho khách thuê",
        "unit": "VND/cây",
        "price": Decimal("20000"),
        "tags": "bida, phụ kiện, gậy",
        "sales_count": 0,
    },
    {
        "name": "Phấn bida",
        "category_key": "billiards",
        "category_name": "Phụ kiện",
        "description": "Phấn bida theo hộp",
        "unit": "VND/hộp",
        "price": Decimal("10000"),
        "tags": "bida, phụ kiện, phấn",
        "sales_count": 0,
    },
]


async def ensure_user_password_column(engine: AsyncEngine) -> None:
    async with engine.begin() as conn:
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)")
        )


async def seed_admin_user(session: AsyncSession) -> User:
    result = await session.execute(select(User).where(User.phone == ADMIN_PHONE))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            phone=ADMIN_PHONE,
            name="Quản lý",
            role=UserRole.ADMIN,
            password_hash=hash_password(ADMIN_PASSWORD),
        )
        session.add(user)
        await session.flush()
        logger.info("Seeded admin user: %s", ADMIN_PHONE)
        return user

    user.name = "Quản lý"
    user.role = UserRole.ADMIN
    if not verify_password(ADMIN_PASSWORD, user.password_hash):
        user.password_hash = hash_password(ADMIN_PASSWORD)
    await session.flush()
    logger.info("Admin user ensured: %s", ADMIN_PHONE)
    return user


async def seed_staff_user(session: AsyncSession) -> User:
    result = await session.execute(select(User).where(User.phone == STAFF_PHONE))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            phone=STAFF_PHONE,
            name="Nhân viên",
            role=UserRole.STAFF,
            password_hash=hash_password(STAFF_PASSWORD),
        )
        session.add(user)
        await session.flush()
        logger.info("Seeded staff user: %s", STAFF_PHONE)
        return user

    user.name = "Nhân viên"
    user.role = UserRole.STAFF
    if not verify_password(STAFF_PASSWORD, user.password_hash):
        user.password_hash = hash_password(STAFF_PASSWORD)
    await session.flush()
    logger.info("Staff user ensured: %s", STAFF_PHONE)
    return user


async def seed_customer_user(session: AsyncSession) -> User:
    result = await session.execute(select(User).where(User.phone == CUSTOMER_PHONE))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            phone=CUSTOMER_PHONE,
            name="Khách hàng",
            role=UserRole.CUSTOMER,
            password_hash=hash_password(CUSTOMER_PASSWORD),
        )
        session.add(user)
        await session.flush()
        logger.info("Seeded customer user: %s", CUSTOMER_PHONE)
        return user

    user.name = "Khách hàng"
    user.role = UserRole.CUSTOMER
    if not verify_password(CUSTOMER_PASSWORD, user.password_hash):
        user.password_hash = hash_password(CUSTOMER_PASSWORD)
    await session.flush()
    logger.info("Customer user ensured: %s", CUSTOMER_PHONE)
    return user


async def seed_default_menu(session: AsyncSession) -> None:
    repo = MenuRepository(session)
    for item in DEFAULT_MENU_ITEMS:
        await repo.upsert_seed_item(**item)
    logger.info("Default menu ensured: %d items", len(DEFAULT_MENU_ITEMS))
