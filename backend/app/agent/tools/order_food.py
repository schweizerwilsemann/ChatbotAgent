import json
import logging

from langchain_core.tools import tool

from app.core.database import async_session_factory
from app.repositories.order_repository import OrderRepository
from app.schemas.order import OrderCreate, OrderItemCreate
from app.services.order_service import OrderService

logger = logging.getLogger(__name__)


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

    try:
        order_items = []
        for item in items_list:
            if "item_name" not in item or "quantity" not in item:
                return "❌ Mỗi món cần có 'item_name' và 'quantity'."
            order_items.append(
                OrderItemCreate(
                    item_name=item["item_name"],
                    quantity=int(item["quantity"]),
                )
            )

        async with async_session_factory() as session:
            repo = OrderRepository(session)
            service = OrderService(repo)

            order_data = OrderCreate(
                user_id="chatbot_user",
                table_number=0,
                items=order_items,
                notes=notes,
            )
            order = await service.create_order(order_data)
            await session.commit()

            items_summary = "\n".join(
                f"  • {item.item_name} x{item.quantity} = {item.unit_price * item.quantity:,.0f} VND"
                for item in order.items
            )

            return (
                f"✅ Đặt hàng thành công!\n"
                f"📋 Mã đơn hàng: {order.id}\n"
                f"🍽️ Chi tiết:\n{items_summary}\n"
                f"💰 Tổng cộng: {order.total_price:,.0f} VND\n"
                f"📝 Ghi chú: {notes or 'Không có'}\n"
                f"⏳ Trạng thái: {order.status}"
            )

    except ValueError as exc:
        return f"❌ Không thể đặt hàng: {exc}"
    except Exception as exc:
        logger.exception("Error in order_food tool")
        return f"❌ Lỗi hệ thống khi đặt hàng: {exc}"
