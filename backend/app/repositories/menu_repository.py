import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.menu import MenuItem


class MenuRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_available(
        self,
        venue_id: str | uuid.UUID | None = None,
    ) -> list[MenuItem]:
        stmt = (
            select(MenuItem)
            .where(
                MenuItem.is_available.is_(True),
                MenuItem.is_deleted.is_(False),
            )
            .order_by(MenuItem.category_key, MenuItem.name)
        )
        if venue_id is not None:
            stmt = stmt.where(
                (MenuItem.venue_id == _to_uuid(venue_id))
                | (MenuItem.venue_id.is_(None))
            )
        else:
            stmt = stmt.where(MenuItem.venue_id.is_(None))
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def top_selling(
        self,
        limit: int = 5,
        venue_id: str | uuid.UUID | None = None,
    ) -> list[MenuItem]:
        stmt = (
            select(MenuItem)
            .where(
                MenuItem.is_available.is_(True),
                MenuItem.is_deleted.is_(False),
            )
            .order_by(MenuItem.sales_count.desc(), MenuItem.name)
            .limit(limit)
        )
        if venue_id is not None:
            stmt = stmt.where(
                (MenuItem.venue_id == _to_uuid(venue_id))
                | (MenuItem.venue_id.is_(None))
            )
        else:
            stmt = stmt.where(MenuItem.venue_id.is_(None))
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def find_available_by_names(
        self,
        names: list[str],
        venue_id: str | uuid.UUID | None = None,
    ) -> dict[str, MenuItem]:
        normalized = [name.lower() for name in names]
        stmt = select(MenuItem).where(
            MenuItem.is_available.is_(True),
            MenuItem.is_deleted.is_(False),
            func.lower(MenuItem.name).in_(normalized),
        )
        if venue_id is not None:
            stmt = stmt.where(
                (MenuItem.venue_id == _to_uuid(venue_id))
                | (MenuItem.venue_id.is_(None))
            )
        else:
            stmt = stmt.where(MenuItem.venue_id.is_(None))
        result = await self._session.execute(stmt)
        return {item.name.lower(): item for item in result.scalars().all()}

    async def search(
        self,
        query: str,
        limit: int = 8,
        venue_id: str | uuid.UUID | None = None,
    ) -> list[MenuItem]:
        normalized = f"%{query.strip().lower()}%"
        stmt = (
            select(MenuItem)
            .where(
                MenuItem.is_available.is_(True),
                MenuItem.is_deleted.is_(False),
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
        if venue_id is not None:
            stmt = stmt.where(
                (MenuItem.venue_id == _to_uuid(venue_id))
                | (MenuItem.venue_id.is_(None))
            )
        else:
            stmt = stmt.where(MenuItem.venue_id.is_(None))
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def increment_sales(
        self,
        quantities_by_name: dict[str, int],
        venue_id: str | uuid.UUID | None = None,
    ) -> None:
        if not quantities_by_name:
            return
        items = await self.find_available_by_names(
            list(quantities_by_name.keys()),
            venue_id=venue_id,
        )
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
        venue_id: str | uuid.UUID | None = None,
    ) -> MenuItem:
        venue_uuid = _to_uuid(venue_id) if venue_id else None
        stmt = select(MenuItem).where(
            func.lower(MenuItem.name) == name.lower(),
            MenuItem.venue_id == venue_uuid,
            MenuItem.is_deleted.is_(False),
        )
        result = await self._session.execute(stmt)
        item = result.scalar_one_or_none()
        if item is None:
            item = MenuItem(
                venue_id=venue_uuid,
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


def _to_uuid(value: str | uuid.UUID | None) -> uuid.UUID | None:
    if value is None:
        return None
    if isinstance(value, uuid.UUID):
        return value
    return uuid.UUID(str(value))
