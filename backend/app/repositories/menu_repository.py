from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.menu import MenuItem


class MenuRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_available(self) -> list[MenuItem]:
        stmt = (
            select(MenuItem)
            .where(MenuItem.is_available.is_(True))
            .order_by(MenuItem.category_key, MenuItem.name)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def top_selling(self, limit: int = 5) -> list[MenuItem]:
        stmt = (
            select(MenuItem)
            .where(MenuItem.is_available.is_(True))
            .order_by(MenuItem.sales_count.desc(), MenuItem.name)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def find_available_by_names(self, names: list[str]) -> dict[str, MenuItem]:
        normalized = [name.lower() for name in names]
        stmt = select(MenuItem).where(
            MenuItem.is_available.is_(True),
            func.lower(MenuItem.name).in_(normalized),
        )
        result = await self._session.execute(stmt)
        return {item.name.lower(): item for item in result.scalars().all()}

    async def search(self, query: str, limit: int = 8) -> list[MenuItem]:
        normalized = f"%{query.strip().lower()}%"
        stmt = (
            select(MenuItem)
            .where(
                MenuItem.is_available.is_(True),
                (
                    func.lower(MenuItem.name).like(normalized)
                    | func.lower(MenuItem.description).like(normalized)
                    | func.lower(MenuItem.tags).like(normalized)
                    | func.lower(MenuItem.category_name).like(normalized)
                ),
            )
            .order_by(MenuItem.sales_count.desc(), MenuItem.name)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def increment_sales(self, quantities_by_name: dict[str, int]) -> None:
        if not quantities_by_name:
            return
        items = await self.find_available_by_names(list(quantities_by_name.keys()))
        for normalized_name, quantity in quantities_by_name.items():
            item = items.get(normalized_name.lower())
            if item is not None:
                item.sales_count += quantity
        await self._session.flush()

    async def upsert_seed_item(
        self,
        *,
        name: str,
        category_key: str,
        category_name: str,
        description: str,
        unit: str,
        price: Decimal,
        tags: str,
        sales_count: int,
    ) -> MenuItem:
        stmt = select(MenuItem).where(func.lower(MenuItem.name) == name.lower())
        result = await self._session.execute(stmt)
        item = result.scalar_one_or_none()
        if item is None:
            item = MenuItem(
                name=name,
                category_key=category_key,
                category_name=category_name,
                description=description,
                unit=unit,
                price=price,
                tags=tags,
                sales_count=sales_count,
                is_available=True,
            )
            self._session.add(item)
        else:
            item.category_key = category_key
            item.category_name = category_name
            item.description = description
            item.unit = unit
            item.price = price
            item.tags = tags
            item.is_available = True
            if item.sales_count == 0:
                item.sales_count = sales_count
        await self._session.flush()
        return item
