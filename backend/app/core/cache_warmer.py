"""Cache Warmer — pre-computes and caches frequently asked queries.

Call during startup to reduce cold-start latency for common questions.
"""

import hashlib
import logging

from app.core.redis_client import redis_client

logger = logging.getLogger(__name__)

# Common knowledge queries to pre-warm in Redis cache
# Format: (query, answer)
PREWARM_QUERIES: list[tuple[str, str]] = [
    # Greeting
    (
        "xin chào",
        "Xin chào! Mình là trợ lý AI của quán thể thao. Mình có thể giúp bạn:\n"
        "• Đặt sân bida, pickleball, cầu lông\n"
        "• Xem thực đơn & gọi đồ\n"
        "• Hỏi luật chơi, kỹ thuật thể thao\n"
        "• Gọi nhân viên hỗ trợ\n\nBạn cần mình giúp gì ạ?",
    ),
    (
        "hello",
        "Xin chào! Mình là trợ lý AI của quán thể thao. Mình có thể giúp bạn:\n"
        "• Đặt sân bida, pickleball, cầu lông\n"
        "• Xem thực đơn & gọi đồ\n"
        "• Hỏi luật chơi, kỹ thuật thể thao\n"
        "• Gọi nhân viên hỗ trợ\n\nBạn cần mình giúp gì ạ?",
    ),
    # Supported sports overview
    (
        "những môn nào được hỗ trợ",
        "Hiện mình hỗ trợ kiến thức luật chơi và kỹ thuật cho 3 môn:\n"
        "1. Bida\n2. Pickleball\n3. Cầu lông\n\n"
        "Bạn muốn tìm kỹ thuật của môn nào trước?",
    ),
    (
        "có những môn gì",
        "Hiện mình hỗ trợ kiến thức luật chơi và kỹ thuật cho 3 môn:\n"
        "1. Bida\n2. Pickleball\n3. Cầu lông\n\n"
        "Bạn muốn tìm kỹ thuật của môn nào trước?",
    ),
    # NOTE: Không pre-warm cache cho câu hỏi giá vì giá khác nhau tùy venue
    # Để LLM query giá thực tế từ DB theo venue context
]

# Pre-warm intent cache for common patterns
PREWARM_INTENT: list[tuple[str, str]] = [
    ("xin chào", "__NONE__"),
    ("hello", "__NONE__"),
    ("hi", "__NONE__"),
    ("chào bạn", "__NONE__"),
    ("đặt sân", "__NONE__"),
    ("thực đơn", "__NONE__"),
    ("menu", "__NONE__"),
    ("gọi đồ", "__NONE__"),
    ("nhân viên", "__NONE__"),
    ("luật bida", "__NONE__"),
    ("luật pickleball", "__NONE__"),
    ("luật cầu lông", "__NONE__"),
    ("kỹ thuật bida", "__NONE__"),
    ("kỹ thuật pickleball", "__NONE__"),
    ("kỹ thuật cầu lông", "__NONE__"),
    ("giá bao nhiêu", "__NONE__"),
    ("giờ mở cửa", "__NONE__"),
    ("đặt bàn", "__NONE__"),
    ("book sân", "__NONE__"),
    ("tính tiền", "__NONE__"),
    ("thanh toán", "__NONE__"),
    ("hủy đặt sân", "__NONE__"),
    ("kiểm tra lịch", "__NONE__"),
    ("gọi nhân viên", "__NONE__"),
    ("có khuyến mãi không", "__NONE__"),
    # Sports overview - definitive answers
    (
        "những môn nào được hỗ trợ",
        "Hiện mình hỗ trợ kiến thức luật chơi và kỹ thuật cho 3 môn:\n"
        "1. Bida\n2. Pickleball\n3. Cầu lông\n\n"
        "Bạn muốn tìm kỹ thuật của môn nào trước?",
    ),
    (
        "bạn hỗ trợ những môn nào",
        "Hiện mình hỗ trợ kiến thức luật chơi và kỹ thuật cho 3 môn:\n"
        "1. Bida\n2. Pickleball\n3. Cầu lông\n\n"
        "Bạn muốn tìm kỹ thuật của môn nào trước?",
    ),
]


def _kg_cache_key(question: str) -> str:
    normalized = " ".join(question.lower().strip().split())
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return f"kg:answer:v1:{digest}"


def _intent_cache_key(message: str) -> str:
    normalized = " ".join(message.lower().strip().split())
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:16]
    return f"intent:{digest}"


async def warm_knowledge_cache() -> int:
    """Pre-warm knowledge graph cache with common queries."""
    count = 0
    for query, answer in PREWARM_QUERIES:
        try:
            key = _kg_cache_key(query)
            exists = await redis_client.exists(key)
            if not exists:
                await redis_client.set(key, answer, ex=21600)  # 6 hours
                count += 1
        except Exception:
            logger.debug("Failed to pre-warm KG cache for '%s'", query)
    return count


async def warm_intent_cache() -> int:
    """Pre-warm intent routing cache with common patterns."""
    count = 0
    for message, result in PREWARM_INTENT:
        try:
            key = _intent_cache_key(message)
            exists = await redis_client.exists(key)
            if not exists:
                await redis_client.set(key, result, ex=600)  # 10 minutes
                count += 1
        except Exception:
            logger.debug("Failed to pre-warm intent cache for '%s'", message)
    return count


async def warm_all_caches() -> None:
    """Pre-warm all caches. Call during startup."""
    kg_count = await warm_knowledge_cache()
    intent_count = await warm_intent_cache()
    logger.info(
        "Cache pre-warmed: %d KG queries, %d intent patterns",
        kg_count,
        intent_count,
    )
