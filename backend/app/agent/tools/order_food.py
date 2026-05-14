import json
import logging
from difflib import SequenceMatcher

from langchain_core.tools import tool

from app.agent.context import current_user_id
from app.core.database import async_session_factory
from app.repositories.menu_repository import MenuRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.order_repository import OrderRepository
from app.schemas.order import OrderCreate, OrderItemCreate
from app.services.notification_service import NotificationService
from app.services.order_service import OrderService

logger = logging.getLogger(__name__)


def _fuzzy_score(query: str, candidate: str) -> float:
    """Score how well *query* matches *candidate* (0.0 – 1.0).

    Uses a combination of substring containment and SequenceMatcher ratio.
    """
    q = query.lower().strip()
    c = candidate.lower().strip()

    # Exact match
    if q == c:
        return 1.0

    # Query is a substring of candidate (e.g. "heineken" in "bia heineken")
    if q in c:
        # Shorter query → lower score but still high
        return 0.6 + 0.4 * (len(q) / len(c))

    # Candidate is a substring of query
    if c in q:
        return 0.6 + 0.4 * (len(c) / len(q))

    # Word-level containment: any query word appears in candidate
    q_words = q.split()
    c_words = c.split()
    word_overlap = sum(1 for w in q_words if w in c_words)
    if word_overlap > 0:
        return 0.4 + 0.4 * (word_overlap / max(len(q_words), len(c_words)))

    # SequenceMatcher ratio as last resort
    return SequenceMatcher(None, q, c).ratio()


def _resolve_item_name(raw_name: str, menu_items: list) -> tuple[str, str | None]:
    """Try to find the best matching menu item for *raw_name*.

    Returns (resolved_name, match_info) where:
    - resolved_name is the canonical menu item name
    - match_info is None for exact match, or a message for fuzzy match
    """
    raw_lower = raw_name.lower().strip()

    # 1. Exact match (case-insensitive)
    for item in menu_items:
        if item.name.lower() == raw_lower:
            return item.name, None

    # 2. Fuzzy match — find the best candidate
    best_score = 0.0
    best_item = None
    for item in menu_items:
        score = _fuzzy_score(raw_lower, item.name)
        if score > best_score:
            best_score = score
            best_item = item

    # Accept fuzzy match if score is high enough
    if best_item and best_score >= 0.45:
        if raw_lower != best_item.name.lower():
            return best_item.name, f"'{raw_name}' → '{best_item.name}'"
        return best_item.name, None

    # No match found
    return raw_name, None


@tool
async def order_food(items: str, notes: str = "") -> str:
    """Đặt đồ ăn/thức uống cho khách. Nhận danh sách món dưới dạng JSON.

    Args:
        items: Danh sách món dạng JSON string, ví dụ: '[{"item_name": "Cà phê đen", "quantity": 2}, {"item_name": "Khô bò", "quantity": 1}]'
        notes: Ghi chú thêm (tùy chọn), ví dụ: "ít đá", "không đường"

    Returns:
        Xác nhận đặt hàng hoặc thông báo lỗi
    """
    try:
        items_list = json.loads(items)
        if not isinstance(items_list, list) or len(items_list) == 0:
            return "❌ Danh sách món không hợp lệ. Vui lòng cung cấp danh sách JSON với item_name và quantity."
    except json.JSONDecodeError:
        return '❌ Định dạng JSON không hợp lệ. Ví dụ: [{"item_name": "Cà phê đen", "quantity": 2}]'

    # ── Pre-process: resolve fuzzy item names ─────────────────────
    async with async_session_factory() as session:
        menu_repo = MenuRepository(session)
        all_available = await menu_repo.list_available()

    resolved_items: list[dict] = []
    match_notes: list[str] = []

    for item_data in items_list:
        if "item_name" not in item_data or "quantity" not in item_data:
            return "❌ Mỗi món cần có 'item_name' và 'quantity'."

        raw_name = item_data["item_name"]
        quantity = int(item_data["quantity"])
        resolved_name, note = _resolve_item_name(raw_name, all_available)

        resolved_items.append({"item_name": resolved_name, "quantity": quantity})
        if note:
            match_notes.append(note)

    # ── Create order ──────────────────────────────────────────────
    order_items: list[OrderItemCreate] = []
    try:
        for item in resolved_items:
            order_items.append(
                OrderItemCreate(
                    item_name=item["item_name"],
                    quantity=int(item["quantity"]),
                )
            )

        async with async_session_factory() as session:
            repo = OrderRepository(session)
            menu_repo = MenuRepository(session)
            notification_service = NotificationService(NotificationRepository(session))
            service = OrderService(repo, menu_repo, notification_service)

            order_data = OrderCreate(
                user_id=current_user_id.get(),
                table_number=0,
                items=order_items,
                notes=notes,
            )
            order = await service.create_order(order_data)
            await session.commit()

            items_summary = "\n".join(
                f"  • {item.item_name} x{item.quantity}"
                f" = {item.unit_price * item.quantity:,.0f} VND"
                for item in order.items
            )

            resolved_note = ""
            if match_notes:
                resolved_note = "\n📝 Đã khớp: " + ", ".join(match_notes)

            return (
                f"✅ Đặt hàng thành công!\n"
                f"📋 Mã đơn hàng: {order.id}\n"
                f"🍽️ Chi tiết:\n{items_summary}\n"
                f"💰 Tổng cộng: {order.total_price:,.0f} VND\n"
                f"📝 Ghi chú: {notes or 'Không có'}"
                f"{resolved_note}\n"
                f"⏳ Trạng thái: {order.status}"
            )

    except ValueError as exc:
        error_msg = str(exc)

        # ── Item not found — suggest alternatives ─────────────────
        if "not found on menu" in error_msg.lower() or "not found" in error_msg.lower():
            # Extract the problematic item name(s)
            unavailable_names: list[str] = []
            for oi in order_items:
                if oi.item_name.lower() in error_msg.lower():
                    unavailable_names.append(oi.item_name)
            if not unavailable_names:
                parts = error_msg.split(":")
                if len(parts) > 1:
                    unavailable_names = [parts[-1].strip()]

            async with async_session_factory() as suggest_session:
                suggest_repo = MenuRepository(suggest_session)
                all_items = await suggest_repo.list_available()

            suggestion_lines: list[str] = []
            for name in unavailable_names:
                name_lower = name.lower()
                similar = [
                    a
                    for a in all_items
                    if name_lower in a.name.lower() or a.name.lower() in name_lower
                ]
                if not similar:
                    for avail in all_items:
                        q_words = name_lower.split()
                        if any(w in avail.name.lower() for w in q_words):
                            similar.append(avail)

                if similar:
                    alt = ", ".join(f"{s.name} ({s.price:,.0f}đ)" for s in similar[:3])
                    suggestion_lines.append(
                        f"  '{name}' không có sẵn → có thể thử: {alt}"
                    )
                else:
                    suggestion_lines.append(f"  '{name}' không có trong thực đơn.")

            if suggestion_lines:
                suggestions_text = "\n".join(suggestion_lines)
                top_items = all_items[:5]
                top_text = "\n".join(
                    f"  • {it.name} — {it.price:,.0f}đ" for it in top_items
                )
                return (
                    f"❌ Một số món không có sẵn:\n"
                    f"{suggestions_text}\n\n"
                    f"📋 Món đang có:\n{top_text}\n\n"
                    f"Bạn muốn thay bằng món nào?"
                )

        return f"❌ Không thể đặt hàng: {exc}"

    except Exception as exc:
        logger.exception("Error in order_food tool")
        return f"❌ Lỗi hệ thống khi đặt hàng: {exc}"
