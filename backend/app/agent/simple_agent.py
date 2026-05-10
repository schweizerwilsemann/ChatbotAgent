import json
import re

from app.agent.agent import AgentResponse
from app.agent.context import current_user_id
from app.core.database import async_session_factory
from app.repositories.menu_repository import MenuRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.order_repository import OrderRepository
from app.schemas.order import OrderCreate, OrderItemCreate
from app.services.notification_service import NotificationService
from app.services.order_service import OrderService


class SimpleVenueAgent:
    """Deterministic dev fallback used when no LLM provider is configured."""

    async def initialize(self) -> None:
        return None

    async def process(self, message: str, session_history: list[dict]) -> AgentResponse:
        text = message.strip().lower()
        if self._is_menu_question(text):
            return AgentResponse(
                output=await self._menu_answer(message),
                tools_used=["menu"],
            )
        if self._is_order_request(text):
            ordered = await self._try_create_order(message)
            if ordered:
                return ordered
            return AgentResponse(
                output=(
                    "Bạn muốn đặt món nào? Hiện mình có thể đặt theo tên món trong thực đơn. "
                    "Ví dụ: đặt 2 Cà phê sữa và 1 Khoai tây chiên."
                ),
                tools_used=[],
            )
        if "đặt sân" in text or "dat san" in text:
            return AgentResponse(
                output=(
                    "Bạn cho mình loại sân, số sân, ngày, giờ bắt đầu và giờ kết thúc. "
                    "Ví dụ: đặt sân billiards số 1 ngày 2026-05-10 từ 19:00 đến 20:00."
                ),
                tools_used=[],
            )
        return AgentResponse(
            output=(
                "Mình có thể hỗ trợ đặt sân, gọi món, xem thực đơn và gọi nhân viên. "
                "Bạn muốn xem 5 món bán chạy hay đặt món cụ thể?"
            ),
            tools_used=[],
        )

    @staticmethod
    def _is_menu_question(text: str) -> bool:
        keywords = ("thực đơn", "menu", "món", "đồ ăn", "đồ uống", "bán chạy", "goi y")
        return any(keyword in text for keyword in keywords)

    @staticmethod
    def _is_order_request(text: str) -> bool:
        return any(keyword in text for keyword in ("đặt", "dat", "gọi", "goi", "mua"))

    async def _menu_answer(self, message: str) -> str:
        async with async_session_factory() as session:
            repo = MenuRepository(session)
            query = self._extract_preference_query(message)
            items = await repo.search(query, limit=5) if query else await repo.top_selling(5)
            if not items:
                items = await repo.top_selling(5)

        if not items:
            return "Thực đơn hiện chưa có dữ liệu."

        lines = [
            "5 món bán chạy/gợi ý hiện tại:"
            if not query
            else f"Mình gợi ý theo sở thích '{query}':"
        ]
        for index, item in enumerate(items, start=1):
            lines.append(f"{index}. {item.name} - {item.price:,.0f} VND")
        lines.append("Bạn có thể nói thêm khẩu vị như ít ngọt, không cay, đồ uống lạnh hoặc món ăn nhẹ.")
        return "\n".join(lines)

    @staticmethod
    def _extract_preference_query(message: str) -> str:
        lowered = message.lower()
        preference_words = [
            "ít ngọt",
            "ngọt",
            "không cay",
            "cay",
            "lạnh",
            "mát",
            "cafe",
            "cà phê",
            "bia",
            "ăn vặt",
            "món nhắm",
        ]
        for word in preference_words:
            if word in lowered:
                return word
        return ""

    async def _try_create_order(self, message: str) -> AgentResponse | None:
        async with async_session_factory() as session:
            menu_repo = MenuRepository(session)
            menu_items = await menu_repo.list_available()
            matched_items: list[OrderItemCreate] = []
            lowered = message.lower()
            for item in menu_items:
                if item.name.lower() not in lowered:
                    continue
                quantity = self._extract_quantity_near_item(message, item.name)
                matched_items.append(
                    OrderItemCreate(item_name=item.name, quantity=quantity)
                )

            if not matched_items:
                return None

            service = OrderService(
                OrderRepository(session),
                menu_repo,
                NotificationService(NotificationRepository(session)),
            )
            order = await service.create_order(
                OrderCreate(
                    user_id=current_user_id.get(),
                    table_number=0,
                    items=matched_items,
                    notes="Đặt qua chatbot dev fallback",
                )
            )
            await session.commit()

        summary = "\n".join(
            f"- {item.item_name} x{item.quantity}: {item.total_price:,.0f} VND"
            for item in order.items
        )
        return AgentResponse(
            output=(
                f"Đặt hàng thành công. Mã đơn: {order.id}\n"
                f"{summary}\n"
                f"Tổng cộng: {order.total_price:,.0f} VND. Nhân viên đã nhận thông báo."
            ),
            tools_used=["order_food"],
        )

    @staticmethod
    def _extract_quantity_near_item(message: str, item_name: str) -> int:
        escaped = re.escape(item_name)
        patterns = [
            rf"(\d+)\s+{escaped}",
            rf"{escaped}\s+x?\s*(\d+)",
        ]
        for pattern in patterns:
            match = re.search(pattern, message, flags=re.IGNORECASE)
            if match:
                return max(1, min(int(match.group(1)), 99))
        return 1
