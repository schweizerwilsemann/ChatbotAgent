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


async def ensure_indexes() -> None:
    """Create fulltext index if it doesn't exist. Call during startup."""
    if not _neo4j_client:
        return
    try:
        # Create fulltext index for knowledge search
        create_query = """
        CREATE FULLTEXT INDEX entity_fulltext IF NOT EXISTS
        FOR (n:Rule|Technique|Equipment|Sport|Concept|GameType)
        ON EACH [n.name, n.description]
        """
        await _neo4j_client.execute_query(create_query)
        logger.info("Neo4j fulltext index 'entity_fulltext' ensured.")
    except Exception as exc:
        logger.debug("Fulltext index creation skipped: %s", exc)


@tool
async def query_knowledge(query: str) -> str:
    """Truy cập knowledge graph để trả lời câu hỏi về luật chơi, kỹ thuật thể thao (bida, pickleball, cầu lông).

    Args:
        query: Câu hỏi của người dùng về luật chơi hoặc kỹ thuật thể thao

    Returns:
        Thông tin liên quan từ knowledge graph
    """
    if not _neo4j_client:
        return "Knowledge graph chưa được kết nối. Vui lòng thử lại sau."

    question = query
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
        CALL db.index.fulltext.queryNodes("entity_fulltext", $question)
        YIELD node, score
        WHERE score > 0.3
        OPTIONAL MATCH (node)-[r]-(related)
        RETURN node.name AS title,
               node.description AS content,
               labels(node)[0] AS sport,
               labels(node) AS labels,
               type(r) AS relationship,
               related.name AS related_title,
               related.description AS related_content,
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
            "Fulltext index 'entity_fulltext' not available, falling back to keyword search"
        )

    # ── 2. Fallback: keyword search with fuzzy matching ──────────────
    try:
        # Extract nouns/keywords by removing common Vietnamese function words
        # Use regex to find Vietnamese words (including diacritics)
        words = question.split()
        # Keep words with 2+ chars, prioritize longer words
        keywords = sorted(
            [w for w in words if len(w) >= 2],
            key=len,
            reverse=True
        )[:5]  # Take top 5 longest words (likely nouns/content words)

        if not keywords:
            keywords = [question]

        # Strategy 1: Try combined keywords
        combined = " ".join(keywords[:3])
        results = await _search_by_keyword(combined)

        # Strategy 2: If no results, try individual keywords (OR logic)
        if not results:
            for kw in keywords:
                if len(kw) < 3:
                    continue
                results = await _search_by_keyword(kw)
                if results:
                    break

        # Strategy 3: If still no results, try partial matching with longest word
        if not results and keywords:
            longest = keywords[0]
            if len(longest) >= 4:
                # Try first 4+ chars as prefix
                results = await _search_by_prefix(longest[:4])

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


async def _search_by_keyword(keyword: str) -> list[dict[str, Any]] | None:
    """Search Neo4j nodes by keyword in name or description."""
    if not _neo4j_client:
        return None
    query = """
    MATCH (n)
    WHERE n.description IS NOT NULL
    AND (toLower(n.description) CONTAINS toLower($keyword)
         OR toLower(n.name) CONTAINS toLower($keyword))
    OPTIONAL MATCH (n)-[r]-(related)
    RETURN n.name AS title,
           n.description AS content,
           labels(n)[0] AS sport,
           labels(n) AS labels,
           type(r) AS relationship,
           related.name AS related_title,
           related.description AS related_content
    LIMIT 5
    """
    try:
        results = await _neo4j_client.execute_query(query, {"keyword": keyword})
        return results if results else None
    except Exception:
        return None


async def _search_by_prefix(prefix: str) -> list[dict[str, Any]] | None:
    """Search Neo4j nodes by prefix using STARTS WITH."""
    if not _neo4j_client:
        return None
    query = """
    MATCH (n)
    WHERE n.description IS NOT NULL
    AND (toLower(n.name) STARTS WITH toLower($prefix)
         OR toLower(n.description) CONTAINS toLower($prefix))
    OPTIONAL MATCH (n)-[r]-(related)
    RETURN n.name AS title,
           n.description AS content,
           labels(n)[0] AS sport,
           labels(n) AS labels,
           type(r) AS relationship,
           related.name AS related_title,
           related.description AS related_content
    LIMIT 5
    """
    try:
        results = await _neo4j_client.execute_query(query, {"prefix": prefix})
        return results if results else None
    except Exception:
        return None
