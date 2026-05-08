"""
Knowledge Graph Query Module.

Provides search and traversal capabilities over the Neo4j knowledge graph
for billiards, pickleball, and badminton sports domain.
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


class KnowledgeGraphQuery:
    """Query interface for the sports knowledge graph stored in Neo4j."""

    def __init__(self, neo4j_client: Any) -> None:
        """
        Initialize the Knowledge Graph Query object.

        Args:
            neo4j_client: A Neo4j async driver or session-compatible object.
        """
        self.neo4j = neo4j_client

    async def search(self, query: str, limit: int = 5) -> list[dict]:
        """
        Full-text search across node names and descriptions.

        Args:
            query: The search query string.
            limit: Maximum number of results to return.

        Returns:
            A list of dicts, each with 'name', 'type', 'description', and 'score'.
        """
        cypher = (
            "CALL db.index.fulltext.queryNodes('entity_fulltext', $query) "
            "YIELD node, score "
            "RETURN node.name AS name, "
            "       labels(node)[0] AS type, "
            "       node.description AS description, "
            "       node.source AS source, "
            "       score "
            "ORDER BY score DESC "
            "LIMIT $limit"
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher, query=query, limit=limit)
                records = await result.data()

                results = []
                for record in records:
                    results.append(
                        {
                            "name": record["name"],
                            "type": record["type"],
                            "description": record["description"] or "",
                            "source": record.get("source") or "",
                            "score": record["score"],
                        }
                    )

                logger.info(
                    "Full-text search for '%s' returned %d results", query, len(results)
                )
                return results

        except Exception as exc:
            logger.warning("Full-text search failed, falling back to CONTAINS: %s", exc)
            return await self._fallback_search(query, limit)

    async def _fallback_search(self, query: str, limit: int = 5) -> list[dict]:
        """
        Fallback search using CONTAINS when full-text index is unavailable.

        Args:
            query: The search query string.
            limit: Maximum number of results.

        Returns:
            A list of matching entity dicts.
        """
        cypher = (
            "MATCH (n) "
            "WHERE n.name CONTAINS $query OR n.description CONTAINS $query "
            "RETURN n.name AS name, "
            "       labels(n)[0] AS type, "
            "       n.description AS description, "
            "       n.source AS source "
            "LIMIT $limit"
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher, query=query, limit=limit)
                records = await result.data()

                results = []
                for record in records:
                    results.append(
                        {
                            "name": record["name"],
                            "type": record["type"],
                            "description": record["description"] or "",
                            "source": record.get("source") or "",
                            "score": 0.5,
                        }
                    )

                logger.info(
                    "Fallback search for '%s' returned %d results", query, len(results)
                )
                return results

        except Exception as exc:
            logger.error("Fallback search also failed: %s", exc)
            return []

    async def get_related(self, entity_name: str, depth: int = 2) -> list[dict]:
        """
        Graph traversal to get entities related to the given entity.

        Args:
            entity_name: The name of the starting entity.
            depth: The traversal depth (number of hops).

        Returns:
            A list of related entity dicts with relationship info.
        """
        depth_val = max(1, min(depth, 5))
        cypher = (
            "MATCH (start {{name: $name}}) "
            f"MATCH path = (start)-[*1..{depth_val}]-(related) "
            "WHERE related <> start "
            "WITH related, relationships(path) AS rels, length(path) AS distance "
            "UNWIND rels AS rel "
            "RETURN DISTINCT related.name AS name, "
            "       labels(related)[0] AS type, "
            "       related.description AS description, "
            "       distance "
            "ORDER BY distance ASC "
            "LIMIT 50"
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher, name=entity_name)
                records = await result.data()

                results = []
                for record in records:
                    results.append(
                        {
                            "name": record["name"],
                            "type": record["type"],
                            "description": record["description"] or "",
                            "distance": record["distance"],
                        }
                    )

                logger.info(
                    "Graph traversal from '%s' (depth=%d) returned %d results",
                    entity_name,
                    depth,
                    len(results),
                )
                return results

        except Exception as exc:
            logger.error("Graph traversal from '%s' failed: %s", entity_name, exc)
            return []

    async def get_entity_by_name(self, name: str) -> dict | None:
        """
        Get an entity by exact name match.

        Args:
            name: The exact entity name.

        Returns:
            The entity dict with all properties, or None if not found.
        """
        cypher = (
            "MATCH (n {name: $name}) "
            "RETURN n.name AS name, "
            "       labels(n)[0] AS type, "
            "       n.description AS description, "
            "       n.source AS source, "
            "       properties(n) AS props"
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher, name=name)
                record = await result.single()

                if record is None:
                    return None

                props = record["props"]
                # Remove internal keys from properties
                entity = {
                    "name": record["name"],
                    "type": record["type"],
                    "description": record["description"] or "",
                    "source": record.get("source") or "",
                    "properties": {
                        k: v
                        for k, v in props.items()
                        if k not in ("name", "description", "source", "updated_at")
                    },
                }
                return entity

        except Exception as exc:
            logger.error("get_entity_by_name('%s') failed: %s", name, exc)
            return None

    async def get_rules_for_sport(self, sport: str) -> list[dict]:
        """
        Get all rules for a specific sport.

        Args:
            sport: The sport name (billiards, pickleball, badminton).

        Returns:
            A list of Rule entity dicts belonging to the given sport.
        """
        cypher = (
            "MATCH (r:Rule)-[:THUOC|DUNG_DE|LIEN_QUAN]->(s:Sport {name: $sport}) "
            "RETURN r.name AS name, "
            "       r.description AS description, "
            "       r.source AS source "
            "UNION "
            "MATCH (r:Rule)-[:THUOC|DUNG_DE|LIEN_QUAN]->(gt:GameType)-[:THUOC]->(s:Sport {name: $sport}) "
            "RETURN r.name AS name, "
            "       r.description AS description, "
            "       r.source AS source"
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher, sport=sport.lower())
                records = await result.data()

                results = []
                seen_names = set()
                for record in records:
                    if record["name"] not in seen_names:
                        seen_names.add(record["name"])
                        results.append(
                            {
                                "name": record["name"],
                                "description": record["description"] or "",
                                "source": record.get("source") or "",
                            }
                        )

                logger.info("Found %d rules for sport '%s'", len(results), sport)
                return results

        except Exception as exc:
            logger.error("get_rules_for_sport('%s') failed: %s", sport, exc)
            return []

    async def get_techniques_for_sport(self, sport: str) -> list[dict]:
        """
        Get all techniques for a specific sport.

        Args:
            sport: The sport name (billiards, pickleball, badminton).

        Returns:
            A list of Technique entity dicts belonging to the given sport.
        """
        cypher = (
            "MATCH (t:Technique)-[:THUOC|DUNG_DE|LIEN_QUAN]->(s:Sport {name: $sport}) "
            "RETURN t.name AS name, "
            "       t.description AS description, "
            "       t.source AS source "
            "UNION "
            "MATCH (t:Technique)-[:THUOC|DUNG_DE|LIEN_QUAN]->(gt:GameType)-[:THUOC]->(s:Sport {name: $sport}) "
            "RETURN t.name AS name, "
            "       t.description AS description, "
            "       t.source AS source"
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher, sport=sport.lower())
                records = await result.data()

                results = []
                seen_names = set()
                for record in records:
                    if record["name"] not in seen_names:
                        seen_names.add(record["name"])
                        results.append(
                            {
                                "name": record["name"],
                                "description": record["description"] or "",
                                "source": record.get("source") or "",
                            }
                        )

                logger.info("Found %d techniques for sport '%s'", len(results), sport)
                return results

        except Exception as exc:
            logger.error("get_techniques_for_sport('%s') failed: %s", sport, exc)
            return []

    async def hybrid_search(
        self,
        query: str,
        embedding: list[float] | None = None,
        limit: int = 5,
    ) -> list[dict]:
        """
        Combine vector similarity search with graph structure.

        If embeddings are available, uses vector similarity on node embeddings
        combined with graph relevance. Falls back to full-text search otherwise.

        Args:
            query: The search query string.
            embedding: Optional query embedding vector for similarity search.
            limit: Maximum number of results.

        Returns:
            A list of relevant entity dicts with scores.
        """
        if embedding is not None:
            try:
                return await self._vector_search(query, embedding, limit)
            except Exception as exc:
                logger.warning(
                    "Vector search failed, falling back to text search: %s", exc
                )

        # Fallback: use full-text search
        text_results = await self.search(query, limit=limit)

        # Enrich results with graph context
        enriched = []
        for result in text_results:
            entity_name = result["name"]
            try:
                related = await self.get_related(entity_name, depth=1)
                result["related_count"] = len(related)
                result["related_entities"] = [
                    {"name": r["name"], "type": r["type"]} for r in related[:5]
                ]
            except Exception:
                result["related_count"] = 0
                result["related_entities"] = []
            enriched.append(result)

        logger.info(
            "Hybrid search (text fallback) for '%s' returned %d results",
            query,
            len(enriched),
        )
        return enriched

    async def _vector_search(
        self, query: str, embedding: list[float], limit: int
    ) -> list[dict]:
        """
        Perform vector similarity search on node embeddings.

        Args:
            query: The original query text (for logging).
            embedding: The query embedding vector.
            limit: Maximum number of results.

        Returns:
            A list of entity dicts sorted by embedding similarity.
        """
        # Use Neo4j vector index if available
        cypher = (
            "CALL db.index.vector.queryNodes('entity_embedding_index', $limit, $embedding) "
            "YIELD node, score "
            "RETURN node.name AS name, "
            "       labels(node)[0] AS type, "
            "       node.description AS description, "
            "       node.source AS source, "
            "       score "
            "ORDER BY score DESC"
        )

        async with self.neo4j.session() as session:
            result = await session.run(cypher, embedding=embedding, limit=limit)
            records = await result.data()

            results = []
            for record in records:
                results.append(
                    {
                        "name": record["name"],
                        "type": record["type"],
                        "description": record["description"] or "",
                        "source": record.get("source") or "",
                        "score": record["score"],
                    }
                )

            logger.info(
                "Vector search for '%s' returned %d results", query, len(results)
            )
            return results

    async def get_all_sports(self) -> list[dict]:
        """
        Get all sport entities in the knowledge graph.

        Returns:
            A list of Sport entity dicts.
        """
        cypher = (
            "MATCH (s:Sport) "
            "RETURN s.name AS name, "
            "       s.description AS description, "
            "       s.source AS source"
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher)
                records = await result.data()

                return [
                    {
                        "name": record["name"],
                        "description": record["description"] or "",
                        "source": record.get("source") or "",
                    }
                    for record in records
                ]

        except Exception as exc:
            logger.error("get_all_sports failed: %s", exc)
            return []

    async def get_entity_neighbors(self, entity_name: str) -> list[dict]:
        """
        Get all direct neighbors of an entity with their relationship types.

        Args:
            entity_name: The entity name to get neighbors for.

        Returns:
            A list of dicts with neighbor info and relationship type.
        """
        cypher = (
            "MATCH (n {name: $name})-[r]-(neighbor) "
            "RETURN neighbor.name AS name, "
            "       labels(neighbor)[0] AS type, "
            "       neighbor.description AS description, "
            "       type(r) AS relationship "
        )

        try:
            async with self.neo4j.session() as session:
                result = await session.run(cypher, name=entity_name)
                records = await result.data()

                return [
                    {
                        "name": record["name"],
                        "type": record["type"],
                        "description": record["description"] or "",
                        "relationship": record["relationship"],
                    }
                    for record in records
                ]

        except Exception as exc:
            logger.error("get_entity_neighbors('%s') failed: %s", entity_name, exc)
            return []
