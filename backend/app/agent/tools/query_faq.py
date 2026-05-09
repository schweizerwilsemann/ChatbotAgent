import hashlib
import json
import logging
from typing import Any

from langchain_core.tools import tool

from app.core.config import settings
from app.core.neo4j_client import Neo4jClient
from app.core.redis_client import redis_client

logger = logging.getLogger(__name__)

_neo4j_client: Neo4jClient | None = None


def set_neo4j_client(client: Neo4jClient) -> None:
    """Set the Neo4j client instance for this tool module."""
    global _neo4j_client
    _neo4j_client = client


@tool
async def query_knowledge(question: str) -> str:
    """Truy cập knowledge graph để trả lời câu hỏi về luật chơi, kỹ thuật thể thao (bida, pickleball, cầu lông).

    Args:
        question: Câu hỏi của người dùng về luật chơi hoặc kỹ thuật thể thao

    Returns:
        Thông tin liên quan từ knowledge graph
    """
    if not _neo4j_client:
        return "Knowledge graph chưa được kết nối. Vui lòng thử lại sau."

    cache_key = _cache_key(question)
    try:
        cached = await redis_client.get(cache_key)
        if cached:
            return cached
    except Exception:
        logger.debug("KG cache read skipped", exc_info=True)

    # ── 1. Try fulltext index search ─────────────────────────────────
    try:
        cypher_query = """
        CALL db.index.fulltext.queryNodes("sport_faq", $question)
        YIELD node, score
        WHERE score > 0.3
        MATCH (node)-[r]-(related)
        RETURN node.title AS title,
               node.content AS content,
               node.sport AS sport,
               labels(node) AS labels,
               type(r) AS relationship,
               related.title AS related_title,
               related.content AS related_content,
               score
        ORDER BY score DESC
        LIMIT 5
        """
        results = await _neo4j_client.execute_query(
            cypher_query, {"question": question}
        )

        if results:
            formatted = _format_results(results)
            await _cache_result(cache_key, formatted)
            return formatted
    except Exception:
        logger.warning(
            "Fulltext index 'sport_faq' not available, falling back to keyword search"
        )

    # ── 2. Fallback: keyword search ───────────────────────────────────
    try:
        fallback_query = """
        MATCH (n)
        WHERE n.content IS NOT NULL
        AND (toLower(n.content) CONTAINS toLower($keyword)
             OR toLower(n.title) CONTAINS toLower($keyword))
        OPTIONAL MATCH (n)-[r]-(related)
        RETURN n.title AS title,
               n.content AS content,
               n.sport AS sport,
               labels(n) AS labels,
               type(r) AS relationship,
               related.title AS related_title,
               related.content AS related_content
        LIMIT 5
        """
        keywords = question.split()[:3]
        keyword = " ".join(keywords) if keywords else question
        results = await _neo4j_client.execute_query(
            fallback_query, {"keyword": keyword}
        )

        if results:
            formatted = _format_results(results)
            await _cache_result(cache_key, formatted)
            return formatted

    except Exception as exc:
        logger.warning("Keyword search also failed: %s", exc)

    # ── 3. Nothing found ──────────────────────────────────────────────
    not_found = "Tôi không tìm thấy thông tin liên quan trong cơ sở dữ liệu. Bạn có thể hỏi cụ thể hơn về bida, pickleball hoặc cầu lông không?"
    await _cache_result(cache_key, not_found, ttl=900)
    return not_found


def _cache_key(question: str) -> str:
    normalized = " ".join(question.lower().strip().split())
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return f"kg:answer:{settings.KG_CACHE_VERSION}:{digest}"


async def _cache_result(
    key: str,
    value: str,
    ttl: int | None = None,
) -> None:
    try:
        await redis_client.set(key, value, ex=ttl or settings.KG_CACHE_TTL_SECONDS)
    except Exception:
        logger.debug("KG cache write skipped", exc_info=True)


def _format_results(results: list[dict[str, Any]]) -> str:
    """Format Neo4j query results into readable text."""
    formatted_parts = []
    seen = set()

    for record in results:
        title = record.get("title", "")
        content = record.get("content", "")

        if title and title not in seen:
            seen.add(title)
            sport = record.get("sport", "")
            section = f"**{title}**"
            if sport:
                section += f" ({sport})"
            if content:
                section += f"\n{content}"

            related_title = record.get("related_title")
            related_content = record.get("related_content")
            if related_title and related_title not in seen:
                seen.add(related_title)
                rel_text = f"\n  → Liên quan: {related_title}"
                if related_content:
                    rel_text += f" — {related_content}"
                section += rel_text

            formatted_parts.append(section)

    return (
        "\n\n".join(formatted_parts)
        if formatted_parts
        else "Không tìm thấy thông tin phù hợp."
    )
