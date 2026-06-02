import json
import re

from app.agent.agent import AgentResponse
from app.agent.context import current_chat_context, current_user_id
from app.core.database import async_session_factory
from app.repositories.booking_repository import BookingRepository
from app.repositories.menu_repository import MenuRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.order_repository import OrderRepository
from app.repositories.staff_request_repository import StaffRequestRepository
from app.repositories.venue_repository import VenueRepository
from app.schemas.order import OrderCreate, OrderItemCreate
from app.services.notification_service import NotificationService
from app.services.order_service import OrderService
from app.services.staff_request_service import StaffRequestService


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
        if self._is_staff_request(text):
            return await self._try_call_staff(message)
        if "đặt sân" in text or "dat san" in text:
            chat_context = current_chat_context.get() or {}
            court_type = chat_context.get("court_type")
            if court_type:
                court_type_name = chat_context.get("court_type_name") or court_type
                venue_name = chat_context.get("venue_name")
                venue_text = f" ở {venue_name}" if venue_name else ""
                resource_kind = "bàn" if court_type == "billiards" else "sân"
                return AgentResponse(
                    output=(
                        f"Mình sẽ đặt {court_type_name}{venue_text}. "
                        f"Bạn cho mình số {resource_kind}, ngày, giờ bắt đầu và giờ kết thúc. "
                        f"Ví dụ: đặt {resource_kind} số 1 ngày 2026-05-10 từ 19:00 đến 20:00."
                    ),
                    tools_used=[],
                )
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
        order_verbs = ("đặt", "dat", "gọi", "goi", "mua", "thuê", "thue", "lấy")
        menu_context = any(
            kw in text
            for kw in (
                "thực đơn",
                "menu",
                "món",
                "đồ ăn",
                "đồ uống",
                "dịch vụ",
                "dich vu",
            )
        )
        item_context = SimpleVenueAgent._has_menu_item_context(text) or menu_context
        if any(kw in text for kw in order_verbs) and item_context:
            return True

        # Implicit: mentions a quantity word + any menu item context
        # e.g. "2 phần", "1 ly", "3 chai", "cho tôi", "cho mình", "lấy"
        quantity_words = (
            "phần",
            "ly",
            "chai",
            "lon",
            "cái",
            "đĩa",
            "tô",
            "cho tôi",
            "cho mình",
            "lấy",
        )
        has_quantity = any(qw in text for qw in quantity_words)
        return has_quantity and item_context

    @staticmethod
    def _has_menu_item_context(text: str) -> bool:
        return any(
            kw in text
            for kw in (
                "khoai",
                "cà phê",
                "cafe",
                "coca",
                "bia",
                "trà",
                "nước",
                "khô bò",
                "khô gà",
                "đậu",
                "bánh",
                "sting",
                "mì",
                "vợt",
                "vot",
                "băng",
                "bang",
                "quấn cán",
                "quan can",
                "cầu lông",
                "cau long",
                "cơ bida",
                "co bida",
                "phụ kiện",
                "phu kien",
            )
        )

    @staticmethod
    def _is_staff_request(text: str) -> bool:
        keywords = (
            "gọi nhân viên",
            "gặp nhân viên",
            "nhờ nhân viên",
            "gọi phục vụ",
            "tính tiền",
            "thanh toán",
            "trả tiền",
            "cần giúp đỡ",
            "cần hỗ trợ",
            "sân bị hư",
            "đèn hỏng",
            "cơ gãy",
            "gọi người",
        )
        return any(kw in text for kw in keywords)

    async def _menu_answer(self, message: str) -> str:
        async with async_session_factory() as session:
            repo = MenuRepository(session)
            query = self._extract_preference_query(message)
            chat_context = current_chat_context.get() or {}
            venue_id = self._optional_str(chat_context.get("venue_id"))
            items = (
                await repo.search(query, limit=5, venue_id=venue_id)
                if query
                else await repo.top_selling(5, venue_id=venue_id)
            )
            if not items:
                items = await repo.top_selling(5, venue_id=venue_id)

        if not items:
            return "Thực đơn hiện chưa có dữ liệu."

        lines = [
            "5 món bán chạy/gợi ý hiện tại:"
            if not query
            else f"Mình gợi ý theo sở thích '{query}':"
        ]
        for index, item in enumerate(items, start=1):
            lines.append(f"{index}. {item.name} - {item.price:,.0f} VND")
        lines.append(
            "Bạn có thể nói thêm khẩu vị như ít ngọt, không cay, đồ uống lạnh hoặc món ăn nhẹ."
        )
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
            chat_context = current_chat_context.get() or {}
            venue_id = self._optional_str(chat_context.get("venue_id"))
            menu_items = await menu_repo.list_available(venue_id=venue_id)
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

            venue_repo = VenueRepository(session)
            service = OrderService(
                OrderRepository(session),
                menu_repo,
                NotificationService(NotificationRepository(session), venue_repo),
                venue_repo,
            )
            user_id = str(current_user_id.get() or "current_user")
            resource_id = None
            resource_label = None
            table_number = 0
            if user_id != "current_user":
                active_booking = await BookingRepository(session).get_active_booking(
                    user_id
                )
                if active_booking and (
                    not venue_id or str(active_booking.venue_id) == str(venue_id)
                ):
                    venue_id = (
                        str(active_booking.venue_id)
                        if active_booking.venue_id
                        else venue_id
                    )
                    resource_id = (
                        str(active_booking.resource_id)
                        if active_booking.resource_id
                        else None
                    )
                    resource_label = active_booking.resource_label
                    table_number = active_booking.court_number
            order = await service.create_order(
                OrderCreate(
                    user_id=user_id,
                    venue_id=venue_id,
                    resource_id=resource_id,
                    resource_label=resource_label,
                    table_number=table_number,
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
            tools_used=["order_menu_items"],
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

    @staticmethod
    def _optional_str(value) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    async def _try_call_staff(self, message: str) -> AgentResponse:
        text = message.lower()
        request_type = "help"
        if any(kw in text for kw in ("tính tiền", "thanh toán", "trả tiền")):
            request_type = "payment"
        elif any(kw in text for kw in ("đồ uống", "mang nước", "gọi đồ")):
            request_type = "order"
        elif any(kw in text for kw in ("hư", "hỏng", "gãy", "đèn", "sân hỏng")):
            request_type = "maintenance"

        async with async_session_factory() as session:
            venue_repo = VenueRepository(session)
            service = StaffRequestService(
                repo=StaffRequestRepository(session),
                notification_service=NotificationService(
                    NotificationRepository(session),
                    venue_repo,
                ),
                venue_repo=venue_repo,
            )
            try:
                result = await service.create_request(
                    user_id=str(current_user_id.get()),
                    user_name=None,
                    request_type=request_type,
                    description=message,
                    table_number=None,
                )
                await session.commit()
                return AgentResponse(
                    output=(
                        f"✅ Đã gọi nhân viên thành công!\n"
                        f"📋 Mã yêu cầu: {result.id}\n"
                        f"⏳ Nhân viên sẽ đến hỗ trợ bạn ngay."
                    ),
                    tools_used=["call_staff"],
                )
            except Exception:
                await session.rollback()
                # Fallback to notification-only
                notif_service = NotificationService(
                    NotificationRepository(session),
                    venue_repo,
                )
                await notif_service.notify_operations(
                    event_type="staff.requested",
                    title="Khách cần hỗ trợ",
                    message=message,
                    source="chatbot",
                    payload={"message": message},
                )
                await session.commit()
                return AgentResponse(
                    output="✅ Đã gọi nhân viên. Nhân viên sẽ đến hỗ trợ bạn ngay.",
                    tools_used=["call_staff"],
                )
