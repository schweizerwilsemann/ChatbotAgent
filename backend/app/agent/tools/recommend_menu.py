from langchain_core.tools import tool

from app.core.database import async_session_factory
from app.repositories.menu_repository import MenuRepository


@tool
async def recommend_menu(preference: str = "", limit: int = 5) -> str:
    """Gợi ý món từ thực đơn PostgreSQL.

    Args:
        preference: Sở thích của khách như "ít ngọt", "cà phê", "không cay", "bia", "ăn vặt". Để trống để lấy món bán chạy.
        limit: Số món muốn gợi ý, mặc định 5.

    Returns:
        Danh sách món phù hợp trong thực đơn hiện có.
    """
    async with async_session_factory() as session:
        repo = MenuRepository(session)
        if preference.strip():
            items = await repo.search(preference, limit=limit)
            heading = f"Gợi ý theo sở thích '{preference}':"
        else:
            items = await repo.top_selling(limit=limit)
            heading = f"Top {limit} món bán chạy nhất:"

    if not items:
        return "Chưa tìm thấy món phù hợp. Bạn có thể hỏi theo vị ngọt, ít cay, đồ uống lạnh hoặc món ăn nhẹ."

    lines = [heading]
    for index, item in enumerate(items, start=1):
        lines.append(
            f"{index}. {item.name} - {item.price:,.0f} VND ({item.description})"
        )
    lines.append(
        "Nếu muốn, hãy nói thêm khẩu vị để mình lọc tiếp từ thực đơn của quán."
    )
    return "\n".join(lines)
