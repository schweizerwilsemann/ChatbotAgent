"""Intent Router — classifies user messages to route them efficiently.

Primary approach: embedding-based semantic similarity.
Fallback: keyword matching (when embedding service is unavailable).
"""

import logging
import math
import unicodedata
from dataclasses import dataclass

logger = logging.getLogger(__name__)

SUPPORTED_SPORTS = ("Bida", "Pickleball", "Cầu lông")


@dataclass(frozen=True)
class IntentResult:
    answer: str


class IntentRouter:
    """Semantic intent router using embedding similarity.

    Falls back to keyword-based matching when the embedding service is down.
    """

    # ── Intent exemplar phrases ───────────────────────────────────────
    _GREETING_EXAMPLES: list[str] = [
        "xin chào",
        "chào bạn",
        "hello",
        "hi",
        "hey",
        "chào buổi sáng",
        "chào buổi tối",
        "bạn ơi",
        "ơi bạn",
        "chào",
        "hế lô",
        "xin chào bạn",
        "chào anh",
        "chào chị",
        "good morning",
        "chào buổi chiều",
        "alo",
        "ô kê",
        "chao ban",
        "xin chao",
        "chào bạn ơi",
        "hello bạn",
        "hi bạn",
        "chào mừng",
        "cảm ơn bạn",
        "thank you",
        "tạm biệt",
    ]

    _OFF_TOPIC_EXAMPLES: list[str] = [
        "thời tiết hôm nay thế nào",
        "cách nấu phở ngon",
        "giá vàng hôm nay",
        "tin tức thể thao mới nhất",
        "điểm thi đại học",
        "cách làm bánh mì",
        "bài hát yêu thích",
        "phim hay nhất năm nay",
        "dự báo thời tiết",
        "giá xăng dầu hôm nay",
        "cách học tiếng anh hiệu quả",
        "đặt vé máy bay giá rẻ",
        "nhà hàng ngon ở hà nội",
        "cách trồng rau sạch",
        "giải toán cao cấp",
        "lập trình python cơ bản",
        "bệnh đau đầu nên uống thuốc gì",
        "mua xe ô tô trả góp",
        "thời tiết hà nội hôm nay",
        "tin tức thời sự trong nước",
        "cách giảm cân nhanh nhất",
        "tử vi hôm nay của tôi",
        "giá điện thoại iphone 15",
        "mẹo chăm sóc da mặt",
        "chính trị thế giới",
        "cổ phiếu hôm nay",
        "mua nhà ở đâu",
        "du lịch đà nẵng",
    ]

    _DOMAIN_EXAMPLES: list[str] = [
        # Pickleball
        "luật pickleball",
        "kỹ thuật pickleball",
        "cách chơi pickleball cho người mới",
        "pickleball là gì",
        "quy tắc pickleball",
        "luật chơi pickleball chi tiết",
        "cho tôi biết luật pickleball",
        "kỹ thuật đánh pickleball nâng cao",
        "pickleball có mấy set",
        "cách phát bóng pickleball",
        # Billiards / Bida
        "luật bida",
        "kỹ thuật bida",
        "cách chơi bida lỗ",
        "bida là gì",
        "quy tắc bida 8 bi",
        "luật chơi bida 9 bi",
        "kỹ thuật đánh bida cơ bản",
        "cách cầm cơ bida",
        "billiards rules",
        "cách đánh bida hay",
        "kỹ thuật kéo cơ bida",
        "cách tính điểm bida",
        # Badminton / Cầu lông
        "luật cầu lông",
        "kỹ thuật cầu lông",
        "cách chơi cầu lông",
        "cầu lông là gì",
        "luật cầu lông mới nhất",
        "kỹ thuật smash cầu lông",
        "cách cầm vợt cầu lông",
        "cách phát cầu lông",
        "kỹ thuật lưới cầu lông",
        # Venue operations — standalone & combined
        "đặt sân",
        "đặt bàn",
        "đặt chỗ",
        "đặt sân bida",
        "đặt sân pickleball",
        "đặt bàn bida",
        "book sân",
        "book sân cầu lông",
        "thực đơn",
        "thực đơn đồ uống",
        "menu quán",
        "gọi đồ ăn",
        "gọi đồ uống",
        "gọi nhân viên",
        "gọi nhân viên hỗ trợ",
        "kiểm tra lịch đặt sân",
        "hủy đặt sân",
        "thay đổi lịch đặt",
        "giá thuê sân",
        "giá bao nhiêu",
        "giờ mở cửa",
        "giờ đóng cửa",
        "mấy giờ mở cửa",
        "địa chỉ quán ở đâu",
        "số điện thoại liên hệ",
        "có khuyến mãi không",
        "ưu đãi hôm nay",
        # Knowledge queries
        "luật chơi thể thao",
        "kỹ thuật thể thao",
        "hướng dẫn chơi",
        "mẹo chơi hay",
        # Food ordering — direct item mentions (no explicit verb)
        "khoai tây chiên 2 phần",
        "cà phê sữa cho tôi",
        "cho tôi 2 coca cola",
        "lấy 1 bia tiger",
        "khoai tây chiên với cafe sữa",
        "2 phần khoai tây chiên và cà phê",
        "1 coca cola và khoai tây chiên",
        "cho tôi cà phê đen",
        "gọi 2 phần khô bò",
        "lấy thêm nước suối",
        "khoai tây chiên 1 phần",
        "cafe sữa đi",
        "trà đá và đậu phộng",
        "bánh tráng trộn 1 phần",
        "khô gà lá chanh 2 phần",
        "bia tiger 3 chai",
        "order khoai tây chiên",
        "mua 2 cà phê sữa",
        # Staff request variants
        "gặp nhân viên",
        "nhờ nhân viên giúp",
        "cần người hỗ trợ",
        "gọi người phục vụ",
        "tính tiền cho tôi",
        "muốn thanh toán",
        "mang thêm nước",
        "sân bị hư",
        "đèn hỏng rồi",
        "cơ bida bị gãy",
        # Non-diacritics variants (model doesn't always bridge these)
        "dat san",
        "dat ban",
        "dat cho",
        "book san",
        "luat bida",
        "luat pickleball",
        "luat cau long",
        "ky thuat bida",
        "ky thuat pickleball",
        "ky thuat cau long",
        "mo cua",
        "gia bao nhieu",
        "o dau",
        "lien he",
        "huy dat san",
        "kiem tra lich",
        "goi nhan vien",
        "tinh tien",
        "thanh toan",
    ]

    _SUPPORTED_SPORTS_EXAMPLES: list[str] = [
        "những môn nào được hỗ trợ",
        "bạn hỗ trợ những môn nào",
        "có những môn gì",
        "hỗ trợ môn nào",
        "cho biết các môn thể thao",
        "quán có những môn nào",
        "mình có thể chơi môn gì ở đây",
        "danh sách môn thể thao",
        "có bida không",
        "có pickleball không",
    ]

    # ── Similarity thresholds ─────────────────────────────────────────
    _GREETING_THRESHOLD = 0.65
    _DOMAIN_THRESHOLD = 0.50
    _SPORTS_OVERVIEW_THRESHOLD = 0.70
    _OFF_TOPIC_THRESHOLD = 0.55

    # ── Keyword fallback data ─────────────────────────────────────────
    _KW_SPORT_KW = ("môn nào", "môn gì", "những môn", "hỗ trợ môn")
    _KW_KNOWLEDGE_KW = ("kỹ thuật", "kĩ thuật", "luật", "kiến thức")

    _KW_DOMAIN_KW: tuple[str, ...] = (
        "bida",
        "billiards",
        "pool",
        "snooker",
        "pickleball",
        "cầu lông",
        "badminton",
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
        "gặp nhân viên",
        "phục vụ",
        "tính tiền",
        "thanh toán",
        "trả tiền",
        "lịch",
        "schedule",
        "lịch sử",
        "đặt trước",
        "hủy",
        "cancel",
        "thay đổi",
        "đổi lịch",
        "luật",
        "kỹ thuật",
        "kĩ thuật",
        "kiến thức",
        "luật chơi",
        "cách chơi",
        "hướng dẫn",
        "mẹo",
        "tip",
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
        # Food items & ordering — direct mentions
        "khoai tây",
        "cà phê",
        "cafe",
        "coca cola",
        "coca",
        "bia tiger",
        "bia",
        "trà đá",
        "nước suối",
        "khô bò",
        "khô gà",
        "đậu phộng",
        "bánh tráng",
        "sting",
        "phần",
        "cho tôi",
        "cho mình",
        "lấy",
        # Maintenance & equipment
        "hư",
        "hỏng",
        "gãy",
        "đèn",
        "quạt",
        "cơ bida",
        "bàn bida",
        "sân hỏng",
    )

    _KW_GREETING_KW: tuple[str, ...] = (
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

    # ══════════════════════════════════════════════════════════════════
    # Construction & initialisation
    # ══════════════════════════════════════════════════════════════════

    def __init__(self, embedder=None) -> None:
        """
        Args:
            embedder: An object with an ``embed_query(text) -> list[float] | None``
                      async method (e.g. ``NodeEmbedder``).  If *None* the router
                      operates in keyword-fallback mode only.
        """
        self._embedder = embedder
        self._greeting_embs: list[list[float]] = []
        self._domain_embs: list[list[float]] = []
        self._sports_embs: list[list[float]] = []
        self._off_topic_embs: list[list[float]] = []
        self._embedding_ready = False

    async def initialize(self) -> None:
        """Pre-compute embeddings for every intent exemplar.

        Call once during application startup, after the embedding service
        (e.g. Ollama) is available.
        """
        if not self._embedder:
            logger.warning("No embedder — IntentRouter stays in keyword-fallback mode")
            return

        logger.info("Pre-computing intent embeddings…")
        self._greeting_embs = await self._precompute(self._GREETING_EXAMPLES)
        self._domain_embs = await self._precompute(self._DOMAIN_EXAMPLES)
        self._sports_embs = await self._precompute(self._SUPPORTED_SPORTS_EXAMPLES)
        self._off_topic_embs = await self._precompute(self._OFF_TOPIC_EXAMPLES)

        total = (
            len(self._greeting_embs)
            + len(self._domain_embs)
            + len(self._sports_embs)
            + len(self._off_topic_embs)
        )
        if total > 0:
            self._embedding_ready = True
            logger.info(
                "Intent embeddings ready — greet=%d  domain=%d  sports=%d  off=%d",
                len(self._greeting_embs),
                len(self._domain_embs),
                len(self._sports_embs),
                len(self._off_topic_embs),
            )
        else:
            logger.warning(
                "All embedding pre-computations failed — staying in keyword mode"
            )

    # ══════════════════════════════════════════════════════════════════
    # Public routing interface
    # ══════════════════════════════════════════════════════════════════

    async def route(self, message: str) -> IntentResult | None:
        """Classify *message* and return an ``IntentResult`` or *None*.

        * ``None`` → message should be forwarded to the LLM.
        * ``IntentResult`` → the router already has a canned answer.

        Uses embeddings when available, keyword matching otherwise.
        """
        if self._embedding_ready:
            return await self._route_embedding(message)
        return self._route_keyword(message)

    # ══════════════════════════════════════════════════════════════════
    # Embedding-based routing (primary)
    # ══════════════════════════════════════════════════════════════════

    async def _route_embedding(self, message: str) -> IntentResult | None:
        query_emb = await self._embedder.embed_query(message)
        if not query_emb:
            logger.warning(
                "Embedding failed for '%s' — falling back to keywords", message[:60]
            )
            return self._route_keyword(message)

        greet_sim = self._max_sim(query_emb, self._greeting_embs)
        domain_sim = self._max_sim(query_emb, self._domain_embs)
        sports_sim = self._max_sim(query_emb, self._sports_embs)
        off_sim = self._max_sim(query_emb, self._off_topic_embs)

        logger.info(
            "Embedding intent '%.50s' → greet=%.3f  domain=%.3f  sports=%.3f  off=%.3f",
            message,
            greet_sim,
            domain_sim,
            sports_sim,
            off_sim,
        )

        # Decision: find the dominant category, check thresholds.
        # Order matters — greetings & domain get priority.

        # 1. Greeting → pass through to LLM
        if greet_sim >= self._GREETING_THRESHOLD and greet_sim >= off_sim:
            return None

        # 2. Domain query → pass through to LLM
        if domain_sim >= self._DOMAIN_THRESHOLD and domain_sim >= off_sim:
            return None

        # 3. Supported-sports overview → canned answer
        #    (only when clearly the top category AND above domain)
        if (
            sports_sim >= self._SPORTS_OVERVIEW_THRESHOLD
            and sports_sim > domain_sim
            and sports_sim > greet_sim
        ):
            return self._make_sports_answer()

        # 4. Off-topic → DO NOT block. Let the LLM handle it.
        #    The LLM's system prompt already constrains the domain.
        #    Blocking here prevents semantic understanding of messages
        #    like food orders that don't match predefined patterns.
        if off_sim >= self._OFF_TOPIC_THRESHOLD and off_sim > domain_sim:
            logger.info(
                "Possible off-topic (embedding, score=%.3f) but passing to LLM: %s",
                off_sim,
                message[:80],
            )

        # 5. Always give the LLM a chance to handle the message
        return None

    # ══════════════════════════════════════════════════════════════════
    # Keyword-based routing (fallback)
    # ══════════════════════════════════════════════════════════════════

    def _route_keyword(self, message: str) -> IntentResult | None:
        text = message.lower().strip()
        norm = self._strip_diacritics(text)

        # 1. Supported-sports overview
        if self._kw_match(norm, self._KW_SPORT_KW) and self._kw_match(
            norm, self._KW_KNOWLEDGE_KW
        ):
            return self._make_sports_answer()

        # 2. Domain relevance check — pass through to LLM even if not matched.
        #    The LLM's system prompt constrains the domain; we no longer block
        #    messages that don't match keywords, because that prevents the LLM
        #    from semantically understanding messages like food orders.
        if not self._kw_is_relevant(text, norm):
            logger.info(
                "Possible off-topic (keyword) but passing to LLM: %s", text[:80]
            )

        return None

    def _kw_is_relevant(self, text: str, norm: str) -> bool:
        if len(text) <= 5:
            return True
        if self._kw_match(norm, self._KW_GREETING_KW):
            return True
        if self._kw_match(norm, self._KW_DOMAIN_KW):
            return True
        return False

    # ══════════════════════════════════════════════════════════════════
    # Canned answers
    # ══════════════════════════════════════════════════════════════════

    @staticmethod
    def _make_sports_answer() -> IntentResult:
        sports = "\n".join(f"{i}. {s}" for i, s in enumerate(SUPPORTED_SPORTS, 1))
        return IntentResult(
            answer=(
                "Hiện mình hỗ trợ kiến thức luật chơi và kỹ thuật cho 3 môn:\n"
                f"{sports}\n\n"
                "Bạn muốn tìm kỹ thuật của môn nào trước?"
            )
        )

    @staticmethod
    def _make_off_topic_answer() -> IntentResult:
        return IntentResult(
            answer=(
                "Xin lỗi, mình chỉ hỗ trợ về bida, pickleball và cầu lông 🎱🏸🏓\n"
                "Bạn có thể hỏi mình về:\n"
                "• Luật chơi, kỹ thuật\n"
                "• Đặt sân\n"
                "• Thực đơn & đặt hàng\n"
                "• Gọi nhân viên hỗ trợ\n"
                "• Kiểm tra lịch sử đặt sân"
            )
        )

    # ══════════════════════════════════════════════════════════════════
    # Utility methods
    # ══════════════════════════════════════════════════════════════════

    async def _precompute(self, examples: list[str]) -> list[list[float]]:
        """Generate embeddings for a list of example phrases."""
        embs: list[list[float]] = []
        for text in examples:
            try:
                emb = await self._embedder.embed_query(text)
                if emb:
                    embs.append(emb)
            except Exception:
                logger.debug("Failed to embed '%s'", text)
        return embs

    @staticmethod
    def _max_sim(query: list[float], category: list[list[float]]) -> float:
        if not category:
            return 0.0
        return max(IntentRouter._cosine(query, e) for e in category)

    @staticmethod
    def _cosine(a: list[float], b: list[float]) -> float:
        dot = sum(x * y for x, y in zip(a, b))
        na = math.sqrt(sum(x * x for x in a))
        nb = math.sqrt(sum(x * x for x in b))
        return dot / (na * nb) if na > 0 and nb > 0 else 0.0

    @staticmethod
    def _strip_diacritics(text: str) -> str:
        """Strip Vietnamese diacritics for fuzzy matching."""
        nfkd = unicodedata.normalize("NFKD", text)
        return "".join(c for c in nfkd if not unicodedata.combining(c))

    @staticmethod
    def _kw_match(norm_text: str, keywords: tuple[str, ...]) -> bool:
        """Word-level keyword matching (diacritics-stripped)."""
        words = norm_text.split()
        for kw in keywords:
            kw_norm = IntentRouter._strip_diacritics(kw)
            kw_parts = kw_norm.split()
            k = len(kw_parts)
            if k == 1:
                if kw_parts[0] in words:
                    return True
            else:
                for i in range(len(words) - k + 1):
                    if words[i : i + k] == kw_parts:
                        return True
        return False
