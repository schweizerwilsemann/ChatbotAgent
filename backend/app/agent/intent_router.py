"""Intent Router — classifies user messages to route them efficiently.

Optimized version with:
- Keyword-first routing (embedding only when needed)
- Redis caching for intent results
- Reduced exemplar phrases for faster embedding
"""

import hashlib
import json
import logging
import math
import unicodedata
from dataclasses import dataclass

from app.core.redis_client import redis_client

logger = logging.getLogger(__name__)

SUPPORTED_SPORTS = ("Bida", "Pickleball", "Cầu lông")

# Cache TTL for intent routing results (10 minutes)
_INTENT_CACHE_TTL = 600
_INTENT_EMBEDDING_CACHE_TTL = 604800


@dataclass(frozen=True)
class IntentResult:
    answer: str


class IntentRouter:
    """Semantic intent router with keyword-first strategy and Redis caching.

    Flow: keyword match → cache check → embedding (only if needed)
    """

    # ── Reduced exemplar phrases (only high-confidence patterns) ──────
    _GREETING_EXAMPLES: list[str] = [
        "xin chào",
        "chào bạn",
        "hello",
        "hi",
        "hey",
        "chào buổi sáng",
        "chào buổi tối",
        "bạn ơi",
        "chào",
        "hế lô",
        "xin chào bạn",
        "chào anh",
        "chào chị",
        "alo",
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
        "phim hay nhất năm nay",
        "dự báo thời tiết",
        "giá xăng dầu hôm nay",
        "cách học tiếng anh hiệu quả",
        "nhà hàng ngon ở hà nội",
        "giải toán cao cấp",
        "lập trình python cơ bản",
        "bệnh đau đầu nên uống thuốc gì",
        "thời tiết hà nội hôm nay",
        "cách giảm cân nhanh nhất",
        "tử vi hôm nay của tôi",
        "chính trị thế giới",
        "cổ phiếu hôm nay",
        "du lịch đà nẵng",
    ]

    _DOMAIN_EXAMPLES: list[str] = [
        # Pickleball core
        "luật pickleball",
        "kỹ thuật pickleball",
        "cách chơi pickleball cho người mới",
        "pickleball là gì",
        "cách phát bóng pickleball",
        # Billiards core
        "luật bida",
        "kỹ thuật bida",
        "cách chơi bida lỗ",
        "bida là gì",
        "cách cầm cơ bida",
        "kỹ thuật kéo cơ bida",
        # Badminton core
        "luật cầu lông",
        "kỹ thuật cầu lông",
        "cách chơi cầu lông",
        "cầu lông là gì",
        "kỹ thuật smash cầu lông",
        "cách cầm vợt cầu lông",
        # Venue operations
        "đặt sân",
        "đặt bàn",
        "đặt chỗ",
        "đặt sân bida",
        "book sân",
        "thực đơn",
        "menu quán",
        "gọi đồ ăn",
        "gọi đồ uống",
        "gọi nhân viên",
        "kiểm tra lịch đặt sân",
        "hủy đặt sân",
        "giá thuê sân",
        "giá bao nhiêu",
        "giờ mở cửa",
        "địa chỉ quán ở đâu",
        "số điện thoại liên hệ",
        "có khuyến mãi không",
        # Knowledge queries
        "luật chơi thể thao",
        "kỹ thuật thể thao",
        "hướng dẫn chơi",
        "mẹo chơi hay",
        # Food ordering - direct item mentions
        "khoai tây chiên 2 phần",
        "cà phê sữa cho tôi",
        "cho tôi 2 coca cola",
        "lấy 1 bia tiger",
        "khoai tây chiên với cafe sữa",
        "cho tôi cà phê đen",
        "gọi 2 phần khô bò",
        "lấy thêm nước suối",
        "thuê vợt cầu lông",
        "thuê vợt pickleball",
        "thuê cơ bida",
        # Staff request
        "gặp nhân viên",
        "nhờ nhân viên giúp",
        "gọi người phục vụ",
        "tính tiền cho tôi",
        "muốn thanh toán",
        # Non-diacritics variants
        "dat san",
        "dat ban",
        "book san",
        "luat bida",
        "luat pickleball",
        "luat cau long",
        "ky thuat bida",
        "ky thuat pickleball",
        "ky thuat cau long",
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

    # ── Keyword data (prioritized for fast matching) ──────────────────
    _KW_SPORT_KW = ("môn nào", "môn gì", "những môn", "hỗ trợ môn")
    _KW_KNOWLEDGE_KW = ("kỹ thuật", "kĩ thuật", "luật", "kiến thức")

    _KW_GREETING_KW: tuple[str, ...] = (
        "xin chào", "hello", "hi", "chào", "hey",
        "cảm ơn", "tks", "thanks", "thank you",
        "tạm biệt", "bye", "goodbye",
        "ơi", "ơi bạn", "bạn ơi",
    )

    _KW_DOMAIN_KW: tuple[str, ...] = (
        "bida", "billiards", "pool", "snooker",
        "pickleball", "cầu lông", "badminton",
        "sân", "court", "đặt sân", "đặt bàn", "book", "đặt chỗ",
        "thực đơn", "menu", "đồ uống", "thức ăn", "đồ ăn",
        "order", "gọi đồ", "gọi món", "đặt hàng",
        "thuê", "thue", "nhân viên", "staff", "hỗ trợ", "support",
        "gọi nhân viên", "gặp nhân viên", "phục vụ",
        "tính tiền", "thanh toán", "trả tiền",
        "lịch", "schedule", "lịch sử", "đặt trước", "hủy", "cancel",
        "thay đổi", "đổi lịch",
        "luật", "kỹ thuật", "kĩ thuật", "kiến thức", "luật chơi",
        "cách chơi", "hướng dẫn", "mẹo", "tip",
        "giá", "giá cả", "bao nhiêu", "bao nhiêu tiền", "chi phí",
        "giờ mở cửa", "địa chỉ", "liên hệ", "số điện thoại",
        "mấy giờ", "ở đâu", "mở cửa", "đóng cửa",
        "khuyến mãi", "giảm giá", "ưu đãi",
        "khoai tây", "cà phê", "cafe", "coca cola", "coca",
        "bia tiger", "bia", "trà đá", "nước suối",
        "khô bò", "khô gà", "đậu phộng", "bánh tráng", "sting",
        "vợt", "vot", "băng đeo tay", "quấn cán", "quan can",
        "cau long", "thuê vợt", "thue vot", "phần",
        "cho tôi", "cho mình", "lấy",
        "hư", "hỏng", "gãy", "đèn", "quạt", "cơ bida", "bàn bida",
    )

    # ══════════════════════════════════════════════════════════════════
    # Construction & initialisation
    # ══════════════════════════════════════════════════════════════════

    def __init__(self, embedder=None) -> None:
        self._embedder = embedder
        self._greeting_embs: list[list[float]] = []
        self._domain_embs: list[list[float]] = []
        self._sports_embs: list[list[float]] = []
        self._off_topic_embs: list[list[float]] = []
        self._embedding_ready = False

    async def initialize(self) -> None:
        """Pre-compute embeddings for every intent exemplar."""
        if not self._embedder:
            logger.warning("No embedder — IntentRouter stays in keyword-fallback mode")
            return

        if await self._load_embedding_cache():
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
            await self._save_embedding_cache()
        else:
            logger.warning(
                "All embedding pre-computations failed — staying in keyword mode"
            )

    def _embedding_cache_key(self) -> str:
        payload = {
            "model": getattr(self._embedder, "model_name", "unknown"),
            "profile": getattr(self._embedder, "embedding_profile", "default"),
            "greeting": self._GREETING_EXAMPLES,
            "domain": self._DOMAIN_EXAMPLES,
            "sports": self._SUPPORTED_SPORTS_EXAMPLES,
            "off_topic": self._OFF_TOPIC_EXAMPLES,
        }
        serialized = json.dumps(
            payload,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        digest = hashlib.sha256(serialized.encode("utf-8")).hexdigest()[:20]
        return f"intent:embeddings:v1:{digest}"

    async def _load_embedding_cache(self) -> bool:
        try:
            cached = await redis_client.get_json(self._embedding_cache_key())
        except Exception:
            logger.debug("Intent embedding cache read skipped", exc_info=True)
            return False

        if not isinstance(cached, dict):
            return False

        groups = (
            cached.get("greeting"),
            cached.get("domain"),
            cached.get("sports"),
            cached.get("off_topic"),
        )
        if not all(isinstance(group, list) for group in groups):
            return False

        (
            self._greeting_embs,
            self._domain_embs,
            self._sports_embs,
            self._off_topic_embs,
        ) = groups
        total = sum(len(group) for group in groups)
        if total == 0:
            return False

        self._embedding_ready = True
        logger.info("Intent embeddings loaded from Redis cache (%d vectors)", total)
        return True

    async def _save_embedding_cache(self) -> None:
        payload = {
            "greeting": self._greeting_embs,
            "domain": self._domain_embs,
            "sports": self._sports_embs,
            "off_topic": self._off_topic_embs,
        }
        try:
            await redis_client.set_json(
                self._embedding_cache_key(),
                payload,
                ex=_INTENT_EMBEDDING_CACHE_TTL,
            )
        except Exception:
            logger.debug("Intent embedding cache write skipped", exc_info=True)

    # ══════════════════════════════════════════════════════════════════
    # Public routing interface
    # ══════════════════════════════════════════════════════════════════

    # Keywords that indicate dynamic content (prices, hours, availability)
    # These should NEVER be cached because they change frequently
    _DYNAMIC_KEYWORDS: tuple[str, ...] = (
        "giá", "giá cả", "bao nhiêu", "bao nhiêu tiền", "chi phí",
        "giờ mở cửa", "giờ đóng cửa", "mấy giờ mở", "mấy giờ đóng",
        "khuyến mãi", "giảm giá", "ưu đãi", "promotion",
        "còn trống", "còn sân", "đang mở", "đang đóng",
    )

    def _is_dynamic_query(self, message: str) -> bool:
        """Check if message asks for dynamic info that shouldn't be cached."""
        text = message.lower().strip()
        norm = self._strip_diacritics(text)
        for kw in self._DYNAMIC_KEYWORDS:
            kw_norm = self._strip_diacritics(kw)
            if kw_norm in norm:
                return True
        return False

    async def route(self, message: str) -> IntentResult | None:
        """Classify message with optimized flow:
        1. Check Redis cache (skip for dynamic queries)
        2. Try keyword matching (fast, no API call)
        3. Try embedding matching (only when keyword is ambiguous)
        """
        is_dynamic = self._is_dynamic_query(message)

        # 1. Check cache first (skip for dynamic queries like price, hours)
        cache_key = self._cache_key(message)
        if not is_dynamic:
            try:
                cached = await redis_client.get(cache_key)
                if cached is not None:
                    if cached == "__NONE__":
                        return None
                    return IntentResult(answer=cached)
            except Exception:
                logger.debug("Intent cache read skipped", exc_info=True)

        # 2. Keyword-first routing (fast path - no API call)
        keyword_result = self._route_keyword(message)

        # If keyword gives a definitive answer (sports overview), use it
        # But DON'T cache dynamic queries
        if keyword_result is not None:
            if not is_dynamic:
                await self._cache_result(cache_key, keyword_result.answer)
            return keyword_result

        # 3. Embedding routing (only when keyword is ambiguous AND embedder available)
        if self._embedding_ready:
            embedding_result = await self._route_embedding(message)
            if embedding_result is not None:
                if not is_dynamic:
                    await self._cache_result(cache_key, embedding_result.answer)
                return embedding_result

        # 4. Pass through to LLM
        # Don't cache dynamic queries at all
        if not is_dynamic:
            await self._cache_result(cache_key, "__NONE__", ttl=120)
        return None

    # ══════════════════════════════════════════════════════════════════
    # Cache helpers
    # ══════════════════════════════════════════════════════════════════

    @staticmethod
    def _cache_key(message: str) -> str:
        normalized = " ".join(message.lower().strip().split())
        digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:16]
        return f"intent:{digest}"

    @staticmethod
    async def _cache_result(key: str, value: str, ttl: int | None = None) -> None:
        try:
            await redis_client.set(key, value, ex=ttl or _INTENT_CACHE_TTL)
        except Exception:
            logger.debug("Intent cache write skipped", exc_info=True)

    # ══════════════════════════════════════════════════════════════════
    # Keyword-based routing (fast path)
    # ══════════════════════════════════════════════════════════════════

    def _route_keyword(self, message: str) -> IntentResult | None:
        text = message.lower().strip()
        norm = self._strip_diacritics(text)

        # 1. Supported-sports overview (definitive answer)
        if self._kw_match(norm, self._KW_SPORT_KW) and self._kw_match(
            norm, self._KW_KNOWLEDGE_KW
        ):
            return self._make_sports_answer()

        # 2. Greeting — pass through to LLM (not definitive)
        if self._kw_match(norm, self._KW_GREETING_KW):
            return None

        # 3. Domain keywords found — pass through to LLM (needs semantic understanding)
        if self._kw_match(norm, self._KW_DOMAIN_KW):
            return None

        # 4. Short messages — let LLM handle
        if len(text) <= 5:
            return None

        # 5. No keyword match — ambiguous, needs embedding check
        return None

    # ══════════════════════════════════════════════════════════════════
    # Embedding-based routing (fallback when keyword is ambiguous)
    # ══════════════════════════════════════════════════════════════════

    async def _route_embedding(self, message: str) -> IntentResult | None:
        query_emb = await self._embed_intent(message)
        if not query_emb:
            logger.warning(
                "Embedding failed for '%s' — falling back to keywords", message[:60]
            )
            return None

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

        # Decision logic
        if greet_sim >= self._GREETING_THRESHOLD and greet_sim >= off_sim:
            return None

        if domain_sim >= self._DOMAIN_THRESHOLD and domain_sim >= off_sim:
            return None

        if (
            sports_sim >= self._SPORTS_OVERVIEW_THRESHOLD
            and sports_sim > domain_sim
            and sports_sim > greet_sim
        ):
            return self._make_sports_answer()

        if off_sim >= self._OFF_TOPIC_THRESHOLD and off_sim > domain_sim:
            logger.info(
                "Possible off-topic (embedding, score=%.3f) but passing to LLM: %s",
                off_sim,
                message[:80],
            )

        return None

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

    # ══════════════════════════════════════════════════════════════════
    # Utility methods
    # ══════════════════════════════════════════════════════════════════

    async def _precompute(self, examples: list[str]) -> list[list[float]]:
        """Generate embeddings for a list of example phrases."""
        embs: list[list[float]] = []
        for text in examples:
            try:
                emb = await self._embed_intent(text)
                if emb:
                    embs.append(emb)
            except Exception:
                logger.debug("Failed to embed '%s'", text)
        return embs

    async def _embed_intent(self, text: str) -> list[float] | None:
        embed_classification = getattr(
            self._embedder,
            "embed_classification",
            None,
        )
        if embed_classification:
            return await embed_classification(text)
        return await self._embedder.embed_query(text)

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
