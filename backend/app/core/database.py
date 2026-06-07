from collections.abc import AsyncGenerator
import logging

from app.core.config import settings
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy import event

logger = logging.getLogger(__name__)

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.APP_ENV == "development",
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=True,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def clear_all_caches() -> None:
    """Clear all SQLAlchemy caches. Call this after major data updates."""
    # Dispose engine to clear connection pool and compiled cache
    await engine.dispose()
    logger.info("SQLAlchemy engine disposed - all caches cleared")


def expire_session_objects(session: AsyncSession) -> None:
    """Expire all objects in a session to force re-fetch from DB."""
    session.expire_all()
    logger.debug("All session objects expired")
