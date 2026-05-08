import json
import logging
from typing import Any

from langchain_core.tools import tool

from app.core.neo4j_client import Neo4jClient

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
            return _format_results(results)

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
            return _format_results(results)

        return "Tôi không tìm thấy thông tin liên quan trong cơ sở dữ liệu. Bạn có thể hỏi cụ thể hơn về bida, pickleball hoặc cầu lông không?"

    except Exception as exc:
        logger.exception("Error querying knowledge graph")
        return f"Lỗi khi truy vấn knowledge graph: {exc}"


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
