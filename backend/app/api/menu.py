from decimal import Decimal
import logging

from fastapi import APIRouter

from app.core.config import settings
from app.core.redis_client import redis_client

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/menu", tags=["menu"])

MENU: dict[str, list[dict]] = {
    "billiards": [
        {"item_name": "Bida lỗ (1 giờ)", "price": 50000, "unit": "VND/giờ"},
        {"item_name": "Bida phăng (1 giờ)", "price": 40000, "unit": "VND/giờ"},
        {"item_name": "Gậy cơ cho thuê", "price": 20000, "unit": "VND/cây"},
        {"item_name": "Phấn bida", "price": 10000, "unit": "VND/hộp"},
    ],
    "drinks": [
        {"item_name": "Cà phê đen", "price": 25000, "unit": "VND/ly"},
        {"item_name": "Cà phê sữa", "price": 30000, "unit": "VND/ly"},
        {"item_name": "Trà đá", "price": 10000, "unit": "VND/ly"},
        {"item_name": "Nước cam", "price": 35000, "unit": "VND/ly"},
        {"item_name": "Coca Cola", "price": 20000, "unit": "VND/lon"},
        {"item_name": "Pepsi", "price": 20000, "unit": "VND/lon"},
        {"item_name": "Bia Heineken", "price": 35000, "unit": "VND/lon"},
        {"item_name": "Bia Tiger", "price": 30000, "unit": "VND/lon"},
        {"item_name": "Bia Sài Gòn", "price": 25000, "unit": "VND/lon"},
        {"item_name": "Nước suối", "price": 10000, "unit": "VND/chai"},
    ],
    "snacks": [
        {"item_name": "Khô bò", "price": 50000, "unit": "VND/phần"},
        {"item_name": "Khô gà", "price": 45000, "unit": "VND/phần"},
        {"item_name": "Mực nướng", "price": 60000, "unit": "VND/phần"},
        {"item_name": "Khoai tây chiên", "price": 40000, "unit": "VND/phần"},
        {"item_name": "Đậu phộng rang", "price": 25000, "unit": "VND/phần"},
        {"item_name": "Xúc xích nướng", "price": 35000, "unit": "VND/phần"},
        {"item_name": "Bánh tráng trộn", "price": 30000, "unit": "VND/phần"},
    ],
}

MENU_CATEGORY_LABELS: dict[str, str] = {
    "drinks": "Đồ uống",
    "snacks": "Đồ ăn",
    "billiards": "Phụ kiện",
}

# Flat lookup: lowercase item_name -> Decimal price (for order total calculation)
MENU_PRICES: dict[str, Decimal] = {}
for _category_items in MENU.values():
    for _item in _category_items:
        MENU_PRICES[_item["item_name"].lower()] = Decimal(str(_item["price"]))


def _menu_payload() -> list[dict]:
    payload: list[dict] = []
    for category_key, items in MENU.items():
        category_name = MENU_CATEGORY_LABELS.get(category_key, category_key)
        payload.append(
            {
                "name": category_name,
                "items": [
                    {
                        "name": item["item_name"],
                        "description": item["unit"],
                        "price": float(item["price"]),
                        "image_url": None,
                        "category": category_name,
                    }
                    for item in items
                ],
            }
        )
    return payload


@router.get("/")
async def get_menu() -> list[dict]:
    """Return the menu in the shape expected by the Flutter app."""
    cache_key = f"menu:{settings.MENU_CACHE_VERSION}"
    try:
        cached = await redis_client.get_json(cache_key)
        if cached is not None:
            return cached
    except Exception:
        logger.debug("Menu cache read skipped", exc_info=True)

    payload = _menu_payload()
    try:
        await redis_client.set_json(
            cache_key,
            payload,
            ex=settings.MENU_CACHE_TTL_SECONDS,
        )
    except Exception:
        logger.debug("Menu cache write skipped", exc_info=True)
    return payload
