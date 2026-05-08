from decimal import Decimal

from fastapi import APIRouter

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

# Flat lookup: lowercase item_name -> Decimal price (for order total calculation)
MENU_PRICES: dict[str, Decimal] = {}
for _category_items in MENU.values():
    for _item in _category_items:
        MENU_PRICES[_item["item_name"].lower()] = Decimal(str(_item["price"]))


@router.get("/")
async def get_menu() -> dict:
    """Return the full menu with categories and prices in VND."""
    return {
        "currency": "VND",
        "categories": MENU,
    }
