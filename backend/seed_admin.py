import asyncio

from app.core.database import async_session_factory, engine
from app.core.seed import ensure_user_password_column, seed_admin_user


async def main() -> None:
    await ensure_user_password_column(engine)
    async with async_session_factory() as session:
        user = await seed_admin_user(session)
        await session.commit()
        print(f"Admin ready: phone={user.phone}, role={user.role.value}")
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
