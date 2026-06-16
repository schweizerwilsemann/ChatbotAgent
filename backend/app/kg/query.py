"""
Knowledge Graph Query Module.

Provides search and traversal capabilities over the Neo4j knowledge graph
for billiards, pickleball, and badminton sports domain.
"""

import asyncio
import logging
import re
import time
import unicodedata
from typing import Any

from app.kg.bilingual import expand_query_terms

logger = logging.getLogger(__name__)


class HybridKnowledgeRetriever:
    """Hybrid full-text/vector retriever enriched with graph context."""

    _ENTITY_LABELS = (
        "Rule",
        "Technique",
        "Equipment",
        "Sport",
        "Concept",
        "GameType",
    )
    _RELATIONSHIPS = (
        "THUOC",
        "DUNG_DE",
        "LIEN_QUAN",
        "LA_LOAI",
        "SU_DUNG",
        "QUY_DINH",
    )
    _RELATION_WEIGHTS = {
        "THUOC": 1.0,
        "QUY_DINH": 1.0,
        "DUNG_DE": 0.9,
        "SU_DUNG": 0.85,
        "LA_LOAI": 0.8,
        "LIEN_QUAN": 0.6,
    }
    _STOP_WORDS = {
        "ai",
        "bao",
        "bi",
        "cac",
        "cach",
        "cho",
        "co",
        "cua",
        "duoc",
        "gi",
        "la",
        "lam",
        "mot",
        "nao",
        "nhu",
        "nhung",
        "o",
        "ra",
        "sao",
        "the",
        "thi",
        "trong",
        "va",
        "ve",
    }
    _SPORT_ALIASES = {
        "billiards": (
            "bida",
            "billiard",
            "billiards",
            "pool",
            "snooker",
            "8 bi",
            "9 bi",
        ),
        "pickleball": ("pickleball",),
        "badminton": ("cau long", "badminton"),
    }
    _QUERY_EXPANSIONS = (
        (("cau long", "badminton"), ("badminton", "shuttlecock", "racket")),
        (("bida", "billiard", "billiards"), ("billiards", "pool", "cue", "ball")),
        (("pickleball",), ("pickleball", "paddle", "serve")),
        (("luat", "quy tac", "quy dinh"), ("rule", "rules", "regulation", "fault")),
        (("loi", "pham loi"), ("fault", "violation", "misconduct")),
        (
            ("giao bong", "giao cau", "phat cau", "phat bong"),
            ("serve", "service", "serving", "server", "receiver", "service court"),
        ),
        (("tinh diem", "diem so"), ("score", "scoring", "rally point")),
        (("san", "san dau"), ("court", "service court", "boundary")),
        (
            ("ky thuat", "ki thuat", "cach danh", "cach choi", "huong dan"),
            ("technique", "shot", "stroke", "strategy"),
        ),
        (("dap cau", "smash"), ("smash", "jump smash", "full smash")),
        (("cam vot", "cach cam vot"), ("grip", "forehand grip", "backhand grip")),
        (("di chuyen", "bo chan"), ("footwork", "lunge", "movement")),
        (("bo nho", "drop", "cat cau"), ("drop shot", "fast drop", "slow drop")),
        (("phong thu", "defense", "defence"), ("defense", "defensive", "block")),
        (("tan cong", "attack"), ("attack", "attacking", "offense")),
    )
    _RRF_K = 60
    _VECTOR_MIN_SCORE = 0.5
    _FULLTEXT_INDEXES = ("entity_fulltext_bilingual", "entity_fulltext")

    def __init__(
        self,
        neo4j_client: Any,
        embedder: Any | None = None,
        embedding_timeout_seconds: float = 3.0,
        embedding_failure_cooldown_seconds: float = 60.0,
    ) -> None:
        self.neo4j = neo4j_client
        self.embedder = embedder
        self.embedding_timeout_seconds = embedding_timeout_seconds
        self.embedding_failure_cooldown_seconds = (
            embedding_failure_cooldown_seconds
        )
        self._embedding_disabled_until = 0.0

    async def retrieve(self, query: str, limit: int = 5) -> list[dict]:
        """Retrieve, fuse and graph-enrich knowledge candidates."""
        limit = max(1, min(limit, 10))
        candidate_limit = max(10, limit * 3)

        fulltext_task = asyncio.create_task(
            self._fulltext_search(query, candidate_limit)
        )
        embedding_task = asyncio.create_task(self._embed_query(query))

        embedding = await embedding_task
        vector_task = None
        if embedding:
            vector_task = asyncio.create_task(
                self._vector_search(
                    embedding,
                    candidate_limit,
                )
            )

        fulltext_results = await fulltext_task
        vector_results: list[dict] = []
        if vector_task:
            try:
                vector_results = await vector_task
            except Exception as exc:
                logger.info("Vector retrieval unavailable; using text search: %s", exc)

        candidates = self._reciprocal_rank_fusion(
            fulltext_results,
            vector_results,
        )
        if not candidates:
            return []

        top_candidates = candidates[:candidate_limit]
        node_ids = [
            candidate["node_id"]
            for candidate in top_candidates
            if candidate.get("node_id")
        ]
        graph_rows = await self._expand_graph(node_ids)
        enriched = self._enrich_with_graph(query, top_candidates, graph_rows)
        return enriched[:limit]

    async def _embed_query(self, query: str) -> list[float] | None:
        if not self.embedder or time.monotonic() < self._embedding_disabled_until:
            return None

        try:
            embedding = await asyncio.wait_for(
                self.embedder.embed_query(query),
                timeout=self.embedding_timeout_seconds,
            )
            if embedding:
                return embedding
        except Exception as exc:
            logger.info("Query embedding unavailable: %s", exc)

        self._embedding_disabled_until = (
            time.monotonic() + self.embedding_failure_cooldown_seconds
        )
        return None

    async def _fulltext_search(self, query: str, limit: int) -> list[dict]:
        lucene_query = self._build_lucene_query(query)
        last_error: Exception | None = None
        for index_name in self._FULLTEXT_INDEXES:
            try:
                results = await self._fulltext_search_index(
                    index_name,
                    lucene_query,
                    limit,
                )
                if results:
                    return results
            except Exception as exc:
                last_error = exc
                logger.info("Full-text index %s unavailable: %s", index_name, exc)

        if last_error:
            logger.info("Full-text retrieval failed; using keyword fallback: %s", last_error)
        return await self._keyword_search(query, limit)

    async def _fulltext_search_index(
        self,
        index_name: str,
        lucene_query: str,
        limit: int,
    ) -> list[dict]:
        cypher = """
        CALL db.index.fulltext.queryNodes($index_name, $query)
        YIELD node, score
        WHERE node.description IS NOT NULL
        RETURN elementId(node) AS node_id,
               node.name AS name,
               node.name_vi AS name_vi,
               head([label IN labels(node)
                     WHERE label IN $entity_labels]) AS type,
               node.description AS description,
               node.description_vi AS description_vi,
               node.source AS source,
               node.search_text AS search_text,
               score
        ORDER BY score DESC
        LIMIT $limit
        """
        return await self.neo4j.execute_query(
            cypher,
            {
                "index_name": index_name,
                "query": lucene_query,
                "limit": limit,
                "entity_labels": list(self._ENTITY_LABELS),
            },
        )

    async def _keyword_search(self, query: str, limit: int) -> list[dict]:
        terms = self._keywords(query)
        if not terms:
            return []

        cypher = """
        MATCH (node)
        WHERE (node:Rule OR node:Technique OR node:Equipment OR node:Sport
               OR node:Concept OR node:GameType)
          AND node.description IS NOT NULL
        WITH node,
             toLower(
                coalesce(node.name, '') + ' ' +
                coalesce(node.description, '') + ' ' +
                coalesce(node.name_vi, '') + ' ' +
                coalesce(node.description_vi, '') + ' ' +
                coalesce(node.search_text, '')
             ) AS search_text
        WHERE any(term IN $terms
                  WHERE search_text CONTAINS term)
        WITH node,
             reduce(matches = 0, term IN $terms |
                 matches + CASE
                     WHEN search_text CONTAINS term
                     THEN 1 ELSE 0 END
             ) AS score
        RETURN elementId(node) AS node_id,
               node.name AS name,
               node.name_vi AS name_vi,
               head([label IN labels(node)
                     WHERE label IN $entity_labels]) AS type,
               node.description AS description,
               node.description_vi AS description_vi,
               node.source AS source,
               node.search_text AS search_text,
               toFloat(score) AS score
        ORDER BY score DESC, size(node.name) ASC
        LIMIT $limit
        """
        try:
            return await self.neo4j.execute_query(
                cypher,
                {
                    "terms": terms,
                    "limit": limit,
                    "entity_labels": list(self._ENTITY_LABELS),
                },
            )
        except Exception as exc:
            logger.warning("Keyword retrieval failed: %s", exc)
            return []

    async def _vector_search(
        self,
        embedding: list[float],
        limit: int,
    ) -> list[dict]:
        cypher = """
        CALL db.index.vector.queryNodes(
            "entity_embedding_index",
            $limit,
            $embedding
        )
        YIELD node, score
        WHERE score >= $min_score
        RETURN elementId(node) AS node_id,
               node.name AS name,
               node.name_vi AS name_vi,
               head([label IN labels(node)
                     WHERE label IN $entity_labels]) AS type,
               node.description AS description,
               node.description_vi AS description_vi,
               node.source AS source,
               node.search_text AS search_text,
               score
        ORDER BY score DESC
        """
        return await self.neo4j.execute_query(
            cypher,
            {
                "embedding": embedding,
                "limit": limit,
                "min_score": self._VECTOR_MIN_SCORE,
                "entity_labels": list(self._ENTITY_LABELS),
            },
        )

    async def _expand_graph(self, node_ids: list[str]) -> list[dict]:
        if not node_ids:
            return []

        cypher = """
        UNWIND $node_ids AS node_id
        MATCH (seed)
        WHERE elementId(seed) = node_id
        MATCH path = (seed)-[*1..2]-(related)
        WHERE related <> seed
          AND related.name IS NOT NULL
          AND all(rel IN relationships(path)
                  WHERE type(rel) IN $relationship_types)
        RETURN DISTINCT elementId(seed) AS seed_id,
               related.name AS related_name,
               head([label IN labels(related)
                     WHERE label IN $entity_labels]) AS related_type,
               related.description AS related_description,
               related.source AS related_source,
               [rel IN relationships(path) | type(rel)] AS relationship_path,
               length(path) AS distance
        ORDER BY distance ASC
        LIMIT $graph_limit
        """
        try:
            return await self.neo4j.execute_query(
                cypher,
                {
                    "node_ids": node_ids,
                    "relationship_types": list(self._RELATIONSHIPS),
                    "entity_labels": list(self._ENTITY_LABELS),
                    "graph_limit": max(50, len(node_ids) * 12),
                },
            )
        except Exception as exc:
            logger.info("Graph expansion unavailable; returning seed nodes: %s", exc)
            return []

    def _reciprocal_rank_fusion(
        self,
        fulltext_results: list[dict],
        vector_results: list[dict],
    ) -> list[dict]:
        merged: dict[str, dict] = {}
        sources = (
            ("fulltext", fulltext_results, 1.0),
            ("vector", vector_results, 1.1),
        )

        for source, results, weight in sources:
            for rank, result in enumerate(results, start=1):
                key = self._candidate_key(result)
                candidate = merged.setdefault(
                    key,
                    {
                        **result,
                        "score": 0.0,
                        "retrieval_sources": [],
                        "raw_scores": {},
                    },
                )
                candidate["score"] += weight / (self._RRF_K + rank)
                candidate["raw_scores"][source] = float(result.get("score") or 0.0)
                if source not in candidate["retrieval_sources"]:
                    candidate["retrieval_sources"].append(source)

        return sorted(
            merged.values(),
            key=lambda item: item["score"],
            reverse=True,
        )

    def _enrich_with_graph(
        self,
        query: str,
        candidates: list[dict],
        graph_rows: list[dict],
    ) -> list[dict]:
        rows_by_seed: dict[str, list[dict]] = {}
        for row in graph_rows:
            seed_id = row.get("seed_id")
            if seed_id:
                rows_by_seed.setdefault(seed_id, []).append(row)

        expected_sport = self._detect_sport(query)
        expected_types = self._detect_entity_types(query)

        for candidate in candidates:
            related_rows = rows_by_seed.get(candidate.get("node_id"), [])
            related_rows.sort(
                key=lambda row: self._graph_row_priority(
                    row,
                    expected_sport,
                    expected_types,
                ),
                reverse=True,
            )

            related_entities = []
            seen_related = set()
            for row in related_rows:
                related_key = (
                    row.get("related_type"),
                    row.get("related_name"),
                )
                if not row.get("related_name") or related_key in seen_related:
                    continue
                seen_related.add(related_key)
                related_entities.append(
                    {
                        "name": row.get("related_name"),
                        "type": row.get("related_type"),
                        "description": row.get("related_description") or "",
                        "source": row.get("related_source") or "",
                        "relationship_path": row.get("relationship_path") or [],
                        "distance": int(row.get("distance") or 1),
                    }
                )
                if len(related_entities) >= 4:
                    break

            graph_boost = min(0.12, len(related_entities) * 0.025)
            if candidate.get("type") in expected_types:
                graph_boost += 0.1
            if expected_sport and self._candidate_matches_sport(
                candidate,
                related_entities,
                expected_sport,
            ):
                graph_boost += 0.15

            candidate["score"] *= 1.0 + graph_boost
            candidate["related_entities"] = related_entities
            candidate["matched_sport"] = (
                expected_sport
                if expected_sport
                and self._candidate_matches_sport(
                    candidate,
                    related_entities,
                    expected_sport,
                )
                else None
            )

        return sorted(candidates, key=lambda item: item["score"], reverse=True)

    def _graph_row_priority(
        self,
        row: dict,
        expected_sport: str | None,
        expected_types: set[str],
    ) -> float:
        path = row.get("relationship_path") or []
        relation_score = sum(
            self._RELATION_WEIGHTS.get(relation, 0.4) for relation in path
        )
        distance = max(1, int(row.get("distance") or 1))
        score = relation_score / distance

        if row.get("related_type") in expected_types:
            score += 0.5
        if expected_sport and self._text_matches_sport(
            f"{row.get('related_name', '')} {row.get('related_description', '')}",
            expected_sport,
        ):
            score += 1.0
        return score

    def _candidate_matches_sport(
        self,
        candidate: dict,
        related_entities: list[dict],
        sport: str,
    ) -> bool:
        candidate_text = (
            f"{candidate.get('name', '')} {candidate.get('name_vi', '')} "
            f"{candidate.get('description', '')} {candidate.get('description_vi', '')} "
            f"{candidate.get('search_text', '')}"
        )
        if self._text_matches_sport(candidate_text, sport):
            return True
        return any(
            self._text_matches_sport(
                f"{related.get('name', '')} {related.get('description', '')}",
                sport,
            )
            for related in related_entities
        )

    def _text_matches_sport(self, text: str, sport: str) -> bool:
        normalized = self._normalize(text)
        return any(
            alias in normalized for alias in self._SPORT_ALIASES.get(sport, ())
        )

    def _detect_sport(self, query: str) -> str | None:
        normalized = self._normalize(query)
        for sport, aliases in self._SPORT_ALIASES.items():
            if any(alias in normalized for alias in aliases):
                return sport
        return None

    def _detect_entity_types(self, query: str) -> set[str]:
        normalized = self._normalize(query)
        types = set()
        if any(word in normalized for word in ("luat", "quy tac", "quy dinh", "loi")):
            types.add("Rule")
        if any(
            word in normalized
            for word in ("ky thuat", "chien thuat", "meo", "cach danh", "smash")
        ):
            types.add("Technique")
        if any(
            word in normalized
            for word in (
                "dung cu",
                "thiet bi",
                "vot",
                "co bida",
                "trai bong",
                "qua cau",
            )
        ):
            types.add("Equipment")
        return types

    def _build_lucene_query(self, query: str) -> str:
        terms = self._keywords(query)
        if not terms:
            return query
        phrase = " ".join(terms)
        if len(terms) == 1:
            return terms[0]
        return f'"{phrase}"^2 OR ' + " OR ".join(terms)

    def _keywords(self, query: str) -> list[str]:
        tokens = re.findall(r"\w+", query.lower(), flags=re.UNICODE)
        keywords = []
        for token in tokens:
            normalized = self._normalize(token)
            if (
                len(normalized) < 2
                and not normalized.isdigit()
            ) or normalized in self._STOP_WORDS:
                continue
            if token not in keywords:
                keywords.append(token)

        normalized_query = self._normalize(query)
        for triggers, expansions in self._QUERY_EXPANSIONS:
            if any(trigger in normalized_query for trigger in triggers):
                for expansion in expansions:
                    for term in re.findall(r"\w+", expansion.lower()):
                        if term not in keywords and term not in self._STOP_WORDS:
                            keywords.append(term)

        for term in expand_query_terms(query):
            for token in re.findall(r"\w+", term.lower(), flags=re.UNICODE):
                normalized = self._normalize(token)
                if normalized in self._STOP_WORDS:
                    continue
                if token not in keywords:
                    keywords.append(token)

        return keywords[:18]

    @staticmethod
    def _candidate_key(result: dict) -> str:
        return str(
            result.get("node_id")
            or f"{result.get('type', '')}:{result.get('name', '')}"
        )

    @staticmethod
    def _normalize(text: str) -> str:
        decomposed = unicodedata.normalize("NFKD", str(text).lower())
        return "".join(
            char for char in decomposed if not unicodedata.combining(char)
        ).replace("đ", "d")


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
