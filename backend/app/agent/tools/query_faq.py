import hashlib
import logging
import re
from typing import Any

from langchain_core.tools import tool

from app.agent.context import current_chat_context
from app.core.config import settings
from app.core.neo4j_client import Neo4jClient
from app.core.redis_client import redis_client
from app.kg.bilingual import bilingual_fulltext_index_cypher, sync_bilingual_fields
from app.kg.query import HybridKnowledgeRetriever

logger = logging.getLogger(__name__)

_neo4j_client: Neo4jClient | None = None
_retriever: HybridKnowledgeRetriever | None = None


def set_neo4j_client(client: Neo4jClient | None, embedder: Any | None = None) -> None:
    """Configure the Neo4j client and optional semantic embedder."""
    global _neo4j_client, _retriever
    _neo4j_client = client
    _retriever = (
        HybridKnowledgeRetriever(
            client,
            embedder=embedder,
            embedding_timeout_seconds=settings.KG_EMBEDDING_TIMEOUT_SECONDS,
            embedding_failure_cooldown_seconds=(
                settings.KG_EMBEDDING_FAILURE_COOLDOWN_SECONDS
            ),
        )
        if client
        else None
    )


async def ensure_indexes() -> None:
    """Create fulltext index if it doesn't exist. Call during startup."""
    if not _neo4j_client:
        return
    try:
        updated = await sync_bilingual_fields(_neo4j_client)
        if updated:
            logger.info("Neo4j bilingual KG fields synced: %d nodes", updated)
        # Create fulltext index for knowledge search
        create_query = """
        CREATE FULLTEXT INDEX entity_fulltext IF NOT EXISTS
        FOR (n:Rule|Technique|Equipment|Sport|Concept|GameType)
        ON EACH [n.name, n.description]
        """
        await _neo4j_client.execute_query(create_query)
        await _neo4j_client.execute_query(bilingual_fulltext_index_cypher())
        logger.info("Neo4j fulltext indexes ensured.")
    except Exception as exc:
        logger.debug("Fulltext index creation skipped: %s", exc)


@tool
async def query_knowledge(query: str) -> str:
    """Tra cứu Knowledge Graph về luật và kỹ thuật bida, pickleball, cầu lông.

    Args:
        query: Câu hỏi của người dùng về luật chơi hoặc kỹ thuật thể thao

    Returns:
        Ngữ cảnh tri thức lấy bằng hybrid full-text/vector retrieval và graph traversal
    """
    if not _retriever:
        return "Knowledge graph chưa được kết nối. Vui lòng thử lại sau."

    question = _clean_query(query)
    cache_key = _cache_key(question)
    try:
        cached = await redis_client.get(cache_key)
        if cached:
            return cached
    except Exception:
        logger.debug("KG cache read skipped", exc_info=True)

    try:
        results = await _retriever.retrieve(question, limit=5)
        if results:
            logger.info(
                "Knowledge retrieval for '%s' returned: %s",
                question[:120],
                ", ".join(
                    str(item.get("name", "")) for item in results[:5]
                ),
            )
            formatted = _format_results(results)
            await _cache_result(cache_key, formatted)
            return formatted
        logger.info("Knowledge retrieval for '%s' returned no results", question[:120])
    except Exception as exc:
        logger.exception("Knowledge retrieval failed: %s", exc)

    not_found = "Tôi không tìm thấy thông tin liên quan trong cơ sở dữ liệu. Bạn có thể hỏi cụ thể hơn về bida, pickleball hoặc cầu lông không?"
    await _cache_result(cache_key, not_found, ttl=900)
    return not_found


def _clean_query(query: str) -> str:
    """Strip internal chat context before retrieval.

    The LLM sometimes passes the full enriched message to the tool. Searching
    with current_datetime, venue_name and resource labels dilutes the sports
    terms, so keep only the actual user question when possible.
    """
    raw = str(query or "").strip()
    raw = re.sub(r"^\[Ngữ cảnh hiện tại:.*?\]\s*", "", raw, flags=re.DOTALL)

    ctx = current_chat_context.get() or {}
    current_message = str(ctx.get("_current_user_message") or "").strip()
    if current_message and (
        not raw
        or "current_datetime=" in raw
        or "venue_name=" in raw
        or len(raw) > len(current_message) + 80
    ):
        raw = current_message

    return _append_context_sport(raw, ctx)


def _append_context_sport(question: str, context: dict) -> str:
    normalized = _strip_diacritics(question.lower())
    if any(
        token in normalized
        for token in ("cau long", "badminton", "pickleball", "bida", "billiard")
    ):
        return question

    context_text = " ".join(
        str(context.get(key) or "")
        for key in ("court_type", "court_type_name", "venue_name")
    )
    context_norm = _strip_diacritics(context_text.lower())
    if "badminton" in context_norm or "cau long" in context_norm:
        return f"{question} cầu lông"
    if "pickleball" in context_norm:
        return f"{question} pickleball"
    if "billiard" in context_norm or "bida" in context_norm:
        return f"{question} bida"

    return question


def _strip_diacritics(text: str) -> str:
    import unicodedata

    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c)).replace("đ", "d")


def _cache_key(question: str) -> str:
    normalized = " ".join(question.lower().strip().split())
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return f"kg:answer:{settings.KG_CACHE_VERSION}:hybrid-v2:{digest}"


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
    """Format hybrid retrieval results as grounded context for the LLM."""
    formatted_parts = []
    seen_primary = set()

    for record in results:
        title = record.get("name", "")
        content = record.get("description", "")

        if title and title not in seen_primary:
            seen_primary.add(title)
            entity_type = record.get("type", "")
            section = f"**{title}**"
            if entity_type:
                section += f" [{entity_type}]"
            if content:
                section += f"\n{content}"

            source = record.get("source")
            if source:
                section += f"\nNguồn: {source}"

            seen_related = {title}
            for related in record.get("related_entities", []):
                related_title = related.get("name")
                if not related_title or related_title in seen_related:
                    continue
                seen_related.add(related_title)
                relationship_path = related.get("relationship_path") or []
                relation_label = " → ".join(relationship_path) or "LIEN_QUAN"
                distance = related.get("distance", 1)
                rel_text = (
                    f"\n- {relation_label} ({distance} bước): {related_title}"
                )
                related_content = related.get("description")
                if related_content:
                    rel_text += f" — {related_content}"
                section += rel_text

            formatted_parts.append(section)

    return (
        "\n\n".join(formatted_parts)
        if formatted_parts
        else "Không tìm thấy thông tin phù hợp."
    )
