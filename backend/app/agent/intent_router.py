import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

SUPPORTED_SPORTS = ("Bida", "Pickleball", "Cầu lông")


@dataclass(frozen=True)
class IntentResult:
    answer: str


class IntentRouter:
    """Deterministic router — handles simple intents without calling the LLM."""

    _sport_keywords = ("môn nào", "môn gì", "những môn", "hỗ trợ môn")
    _knowledge_keywords = ("kỹ thuật", "kĩ thuật", "luật", "kiến thức")

    # ── Domain keywords: anything related to our venue / sports ───────
    _domain_keywords: tuple[str, ...] = (
        # Sports names
        "bida",
        "billiards",
        "pool",
        "snooker",
        "pickleball",
        "cầu lông",
        "badminton",
        # Venue operations
        "sân",
        "court",
        "đặt sân",
        "đặt bàn",
        "book",
        "đặt chỗ",
        "thực đơn",
        "menu",
        "đồ uống",
        "thức ăn",
        "đồ ăn",
        "order",
        "gọi đồ",
        "gọi món",
        "đặt hàng",
        "nhân viên",
        "staff",
        "hỗ trợ",
        "support",
        "gọi nhân viên",
        "lịch",
        "schedule",
        "lịch sử",
        "đặt trước",
        "hủy",
        "cancel",
        "thay đổi",
        "đổi lịch",
        # Knowledge
        "luật",
        "kỹ thuật",
        "kĩ thuật",
        "kiến thức",
        "luật chơi",
        "cách chơi",
        "hướng dẫn",
        "mẹo",
        "tip",
        # General venue info
        "giá",
        "giờ mở cửa",
        "địa chỉ",
        "liên hệ",
        "số điện thoại",
        "mấy giờ",
        "ở đâu",
        "bao nhiêu",
        "mở cửa",
        "đóng cửa",
        "khuyến mãi",
        "giảm giá",
        "ưu đãi",
    )

    # ── Greetings / polite phrases (always let through) ───────────────
    _greeting_keywords: tuple[str, ...] = (
        "xin chào",
        "hello",
        "hi",
        "chào",
        "hey",
        "cảm ơn",
        "tks",
        "thanks",
        "thank you",
        "tạm biệt",
        "bye",
        "goodbye",
        "ơi",
        "ơi bạn",
        "bạn ơi",
    )

    # ───────────────────────────────────────────────────────────────────
    def route(self, message: str) -> IntentResult | None:
        text = message.lower().strip()

        # 1. Supported-sports overview question (cheap answer)
        if self._is_supported_sports_question(text):
            sports = "\n".join(f"{i}. {s}" for i, s in enumerate(SUPPORTED_SPORTS, 1))
            return IntentResult(
                answer=(
                    "Hiện mình hỗ trợ kiến thức luật chơi và kỹ thuật cho 3 môn:\n"
                    f"{sports}\n\n"
                    "Bạn muốn tìm kỹ thuật của môn nào trước?"
                )
            )

        # 2. Domain filter — block off-topic questions (saves tokens)
        if not self._is_relevant(text):
            logger.info("Off-topic blocked: %s", text[:80])
            return IntentResult(
                answer=(
                    "Xin lỗi, mình chỉ hỗ trợ về bida, pickleball và cầu lông 🎱🏸🏓\n"
                    "Bạn có thể hỏi mình về:\n"
                    "• Luật chơi, kỹ thuật\n"
                    "• Đặt sân\n"
                    "• Thực đơn & đặt hàng\n"
                    "• Gọi nhân viên hỗ trợ"
                )
            )

        return None

    # ───────────────────────────────────────────────────────────────────
    def _is_relevant(self, text: str) -> bool:
        """Return True if the message is related to our domain."""
        # Very short messages (greetings, "ok", "ừ", etc.) — always pass
        if len(text) <= 5:
            return True

        # Greetings — always pass
        if any(g in text for g in self._greeting_keywords):
            return True

        # Domain keywords
        if any(kw in text for kw in self._domain_keywords):
            return True

        return False

    def _is_supported_sports_question(self, text: str) -> bool:
        return any(kw in text for kw in self._sport_keywords) and any(
            kw in text for kw in self._knowledge_keywords
        )
