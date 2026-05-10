import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.redis_client import redis_client
from app.repositories.menu_repository import MenuRepository
from app.schemas.menu import (
    MenuCategoryResponse,
    MenuItemResponse,
    MenuSuggestionResponse,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/menu", tags=["menu"])

CATEGORY_ORDER = ["drinks", "snacks", "billiards"]


def _item_payload(item) -> MenuItemResponse:
    return MenuItemResponse(
        id=str(item.id),
        name=item.name,
        description=item.description or item.unit,
        price=item.price,
        image_url=item.image_url,
        category=item.category_name,
        category_key=item.category_key,
        unit=item.unit,
        tags=item.tags,
        sales_count=item.sales_count,
        is_available=item.is_available,
        created_at=getattr(item, "created_at", None),
        updated_at=getattr(item, "updated_at", None),
    )


def _group_menu(items: list) -> list[MenuCategoryResponse]:
    grouped: dict[str, MenuCategoryResponse] = {}
    for item in items:
        grouped.setdefault(
            item.category_key,
            MenuCategoryResponse(name=item.category_name, items=[]),
        ).items.append(_item_payload(item))

    ordered: list[MenuCategoryResponse] = []
    for key in CATEGORY_ORDER:
        if key in grouped:
            ordered.append(grouped.pop(key))
    ordered.extend(grouped.values())
    return ordered


@router.get("/", response_model=list[MenuCategoryResponse])
async def get_menu(
    session: AsyncSession = Depends(get_db),
) -> list[MenuCategoryResponse]:
    """Return menu grouped by category from PostgreSQL."""
    cache_key = f"menu:{settings.MENU_CACHE_VERSION}"
    try:
        cached = await redis_client.get_json(cache_key)
        if cached is not None:
            return [MenuCategoryResponse.model_validate(item) for item in cached]
    except Exception:
        logger.debug("Menu cache read skipped", exc_info=True)

    repo = MenuRepository(session)
    payload = _group_menu(await repo.list_available())
    try:
        await redis_client.set_json(
            cache_key,
            [category.model_dump(mode="json") for category in payload],
            ex=settings.MENU_CACHE_TTL_SECONDS,
        )
    except Exception:
        logger.debug("Menu cache write skipped", exc_info=True)
    return payload


@router.get("/top-selling", response_model=list[MenuItemResponse])
async def get_top_selling_menu(
    limit: int = Query(5, ge=1, le=20),
    session: AsyncSession = Depends(get_db),
) -> list[MenuItemResponse]:
    repo = MenuRepository(session)
    return [_item_payload(item) for item in await repo.top_selling(limit=limit)]


@router.get("/suggest", response_model=MenuSuggestionResponse)
async def suggest_menu(
    q: str = Query("", max_length=200),
    session: AsyncSession = Depends(get_db),
) -> MenuSuggestionResponse:
    repo = MenuRepository(session)
    query = q.strip()
    if query:
        items = await repo.search(query, limit=8)
        prompt = "Mình lọc món theo sở thích của bạn. Bạn muốn vị ngọt, ít ngọt, món ăn nhẹ hay đồ uống lạnh?"
    else:
        items = await repo.top_selling(limit=5)
        prompt = "Đây là 5 món bán chạy nhất. Bạn có thể nói khẩu vị để mình gợi ý sát hơn."
    return MenuSuggestionResponse(
        query=query,
        items=[_item_payload(item) for item in items],
        prompt=prompt,
    )
