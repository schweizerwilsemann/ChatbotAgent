import logging

from app.core.security import hash_password, verify_password
from app.models.user import User, UserRole
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

logger = logging.getLogger(__name__)

ADMIN_PHONE = "0123456789"
ADMIN_PASSWORD = "123456"


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
            name="Admin",
            role=UserRole.ADMIN,
            password_hash=hash_password(ADMIN_PASSWORD),
        )
        session.add(user)
        await session.flush()
        logger.info("Seeded admin user: %s", ADMIN_PHONE)
        return user

    user.name = "Admin"
    user.role = UserRole.ADMIN
    if not verify_password(ADMIN_PASSWORD, user.password_hash):
        user.password_hash = hash_password(ADMIN_PASSWORD)
    await session.flush()
    logger.info("Admin user ensured: %s", ADMIN_PHONE)
    return user
