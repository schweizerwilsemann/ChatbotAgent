"""
Node Embeddings Module.

Generates and stores vector embeddings for knowledge graph nodes.
Supports external embedding API calls for high-quality embeddings.
"""

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any

import httpx

logger = logging.getLogger(__name__)


class NodeEmbedder:
    """Generates and stores embeddings for knowledge graph nodes in Neo4j."""

    _ENTITY_LABELS = (
        "Rule",
        "Technique",
        "Equipment",
        "Sport",
        "Concept",
        "GameType",
    )

    def __init__(
        self,
        embedding_api_url: str = "http://localhost:11434/api/embeddings",
        model_name: str = "nomic-embed-text",
        batch_size: int = 16,
        max_concurrent: int = 4,
    ) -> None:
        """
        Initialize the Node Embedder.

        Args:
            embedding_api_url: URL for the embedding API endpoint (e.g., Ollama).
            model_name: The embedding model name to use.
            batch_size: Number of nodes to embed per batch.
            max_concurrent: Maximum concurrent API requests.
        """
        self.embedding_api_url = embedding_api_url
        self.model_name = model_name
        self.batch_size = batch_size
        self.max_concurrent = max_concurrent
        self.embedding_profile = (
            "nomic-v1.5-task-prefix-v1"
            if "nomic-embed-text" in model_name.lower()
            else "default-v1"
        )

    async def _generate_embedding(self, text: str) -> list[float] | None:
        """
        Generate an embedding vector for a single text string.

        Args:
            text: The text to embed.

        Returns:
            A list of floats representing the embedding, or None on failure.
        """
        payload = {
            "model": self.model_name,
            "prompt": text,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(self.embedding_api_url, json=payload)
                response.raise_for_status()
                data = response.json()

                embedding = data.get("embedding")
                if embedding and isinstance(embedding, list):
                    return embedding

                logger.warning(
                    "Unexpected embedding API response format: %s", list(data.keys())
                )
                return None

        except httpx.HTTPStatusError as exc:
            logger.error(
                "Embedding API HTTP error: %s - %s",
                exc.response.status_code,
                exc.response.text[:200],
            )
            return None
        except httpx.RequestError as exc:
            logger.error("Embedding API request error: %s", exc)
            return None
        except Exception as exc:
            logger.error("Unexpected error generating embedding: %s", exc)
            return None

    async def _generate_embeddings_batch(
        self, texts: list[str]
    ) -> list[list[float] | None]:
        """
        Generate embeddings for a batch of texts with concurrency control.

        Args:
            texts: List of text strings to embed.

        Returns:
            A list of embedding vectors (or None for failures).
        """
        semaphore = asyncio.Semaphore(self.max_concurrent)

        async def _embed_with_semaphore(text: str) -> list[float] | None:
            async with semaphore:
                return await self._generate_embedding(text)

        tasks = [_embed_with_semaphore(text) for text in texts]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        embeddings = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error("Embedding failed for text[%d]: %s", i, result)
                embeddings.append(None)
            else:
                embeddings.append(result)

        return embeddings

    def _prepare_embedding_text(self, node: dict) -> str:
        """
        Prepare the text to embed from a node's name and description.

        Args:
            node: A dict with 'name', 'description', and optionally 'type'.

        Returns:
            A combined text string for embedding.
        """
        name = node.get("name", "")
        description = node.get("description", "")
        search_text = node.get("search_text", "")
        node_type = node.get("type", "")

        parts = []
        if node_type:
            parts.append(f"[{node_type}]")
        if search_text:
            parts.append(search_text)
        else:
            parts.append(name)
            if description and description != name:
                parts.append(description)

        return self._task_text("search_document", " ".join(parts))

    async def generate_embeddings(self, nodes: list[dict]) -> list[list[float] | None]:
        """
        Generate embeddings for a list of nodes.

        Args:
            nodes: List of node dicts with 'name', 'description', 'type'.

        Returns:
            A list of embedding vectors corresponding to each node.
        """
        if not nodes:
            return []

        texts = [self._prepare_embedding_text(node) for node in nodes]

        all_embeddings: list[list[float] | None] = []
        total_batches = (len(texts) + self.batch_size - 1) // self.batch_size

        for batch_idx in range(0, len(texts), self.batch_size):
            batch_texts = texts[batch_idx : batch_idx + self.batch_size]
            batch_num = batch_idx // self.batch_size + 1

            logger.info(
                "Generating embeddings for batch %d/%d (%d texts)",
                batch_num,
                total_batches,
                len(batch_texts),
            )

            batch_embeddings = await self._generate_embeddings_batch(batch_texts)
            all_embeddings.extend(batch_embeddings)

            # Brief pause between batches to avoid rate limiting
            if batch_idx + self.batch_size < len(texts):
                await asyncio.sleep(0.5)

        success_count = sum(1 for e in all_embeddings if e is not None)
        logger.info(
            "Generated %d/%d embeddings successfully",
            success_count,
            len(all_embeddings),
        )
        return all_embeddings

    async def embed_and_store(self, neo4j_client: Any, nodes: list[dict]) -> int:
        """
        Generate embeddings for nodes and store them back in Neo4j.

        Args:
            neo4j_client: A Neo4j async driver or session-compatible object.
            nodes: List of node dicts with 'name', 'type', 'description'.

        Returns:
            The number of nodes successfully embedded and stored.
        """
        if not nodes:
            logger.info("No nodes to embed")
            return 0

        # Step 1: Generate embeddings
        embeddings = await self.generate_embeddings(nodes)

        first_embedding = next((item for item in embeddings if item), None)
        if not first_embedding:
            logger.warning("No embeddings generated; nothing will be stored")
            return 0

        # Step 2: Create vector index if it doesn't exist
        await self._ensure_vector_index(neo4j_client, len(first_embedding))

        # Step 3: Store embeddings in Neo4j
        rows = []
        for node, embedding in zip(nodes, embeddings):
            if not embedding or not node.get("name"):
                continue
            rows.append(
                {
                    "node_id": node.get("node_id"),
                    "name": node["name"],
                    "type": node.get("type", "Concept"),
                    "embedding": embedding,
                    "embedding_source": self._embedding_source(node),
                }
            )

        stored_count = await self._store_embeddings(neo4j_client, rows)

        logger.info(
            "Stored embeddings for %d/%d nodes",
            stored_count,
            len(nodes),
        )
        return stored_count

    async def sync_missing_embeddings(
        self,
        neo4j_client: Any,
        max_nodes: int = 500,
    ) -> dict[str, int]:
        """Embed only missing or stale knowledge nodes.

        A node is stale when its name/description or embedding model changed.
        This method is safe to invoke on every backend startup.
        """
        await self._apply_entity_label(neo4j_client)
        nodes = await self._fetch_stale_nodes(neo4j_client, max_nodes)

        if not nodes:
            dimension = await self._existing_embedding_dimension(neo4j_client)
            if dimension:
                await self._ensure_vector_index(neo4j_client, dimension)
            logger.info("Knowledge embeddings are already up to date")
            return {"checked": 0, "stored": 0}

        embeddings = await self.generate_embeddings(nodes)
        first_embedding = next((item for item in embeddings if item), None)
        if not first_embedding:
            logger.warning("Knowledge embedding sync produced no vectors")
            return {"checked": len(nodes), "stored": 0}

        await self._ensure_vector_index(neo4j_client, len(first_embedding))

        rows = []
        for node, embedding in zip(nodes, embeddings):
            if not embedding:
                continue
            rows.append(
                {
                    "node_id": node["node_id"],
                    "name": node["name"],
                    "type": node["type"],
                    "embedding": embedding,
                    "embedding_source": node["embedding_source"],
                }
            )

        stored = await self._store_embeddings(neo4j_client, rows)
        logger.info(
            "Knowledge embedding sync complete: checked=%d stored=%d",
            len(nodes),
            stored,
        )
        return {"checked": len(nodes), "stored": stored}

    async def _apply_entity_label(self, neo4j_client: Any) -> None:
        cypher = """
        MATCH (n)
        WHERE n:Rule OR n:Technique OR n:Equipment OR n:Sport
           OR n:Concept OR n:GameType
        SET n:KnowledgeEntity
        """
        await self._execute_query(neo4j_client, cypher)

    async def _fetch_stale_nodes(
        self,
        neo4j_client: Any,
        max_nodes: int,
    ) -> list[dict]:
        cypher = """
        MATCH (n:KnowledgeEntity)
        WITH n,
             CASE
               WHEN coalesce(n.search_text, '') <> ''
               THEN n.search_text
               ELSE coalesce(n.name, '') + '\n' + coalesce(n.description, '')
             END
                 AS embedding_source
        WHERE n.name IS NOT NULL
          AND (
              n.embedding IS NULL
              OR coalesce(n.embedding_model, '') <> $model
              OR coalesce(n.embedding_profile, '') <> $profile
              OR coalesce(n.embedding_source, '') <> embedding_source
          )
        RETURN elementId(n) AS node_id,
               n.name AS name,
               head([label IN labels(n)
                     WHERE label IN $entity_labels]) AS type,
               n.description AS description,
               n.search_text AS search_text,
               embedding_source
        ORDER BY n.name
        LIMIT $limit
        """
        return await self._execute_query(
            neo4j_client,
            cypher,
            {
                "model": self.model_name,
                "profile": self.embedding_profile,
                "entity_labels": list(self._ENTITY_LABELS),
                "limit": max(1, max_nodes),
            },
        )

    async def _store_embeddings(
        self,
        neo4j_client: Any,
        rows: list[dict],
    ) -> int:
        if not rows:
            return 0

        cypher = """
        UNWIND $rows AS row
        MATCH (n)
        WHERE (row.node_id IS NOT NULL AND elementId(n) = row.node_id)
           OR (row.node_id IS NULL
               AND row.type IN labels(n)
               AND n.name = row.name)
        SET n.embedding = row.embedding,
            n.embedding_model = $model,
            n.embedding_profile = $profile,
            n.embedding_source = row.embedding_source,
            n.embedding_updated_at = datetime($updated_at),
            n:KnowledgeEntity
        RETURN count(DISTINCT n) AS stored
        """
        result = await self._execute_query(
            neo4j_client,
            cypher,
            {
                "rows": rows,
                "model": self.model_name,
                "profile": self.embedding_profile,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            },
        )
        return int(result[0]["stored"]) if result else 0

    async def _existing_embedding_dimension(self, neo4j_client: Any) -> int | None:
        cypher = """
        MATCH (n:KnowledgeEntity)
        WHERE n.embedding IS NOT NULL
        RETURN size(n.embedding) AS dimension
        LIMIT 1
        """
        result = await self._execute_query(neo4j_client, cypher)
        if not result or not result[0].get("dimension"):
            return None
        return int(result[0]["dimension"])

    async def _ensure_vector_index(
        self,
        neo4j_client: Any,
        dimension: int | None = None,
    ) -> None:
        """
        Ensure the vector index for node embeddings exists in Neo4j.

        Args:
            neo4j_client: A Neo4j async driver or session-compatible object.
        """
        if dimension is None:
            dimension = await self._existing_embedding_dimension(neo4j_client)
        if dimension is None:
            test_embedding = await self._generate_embedding("test")
            if test_embedding is None:
                logger.error("Cannot determine embedding dimension; API not available")
                return
            dimension = len(test_embedding)
        logger.info("Detected embedding dimension: %d", dimension)

        index_cypher = (
            "CREATE VECTOR INDEX entity_embedding_index IF NOT EXISTS "
            "FOR (n:KnowledgeEntity) "
            f"ON (n.embedding) "
            f"OPTIONS {{indexConfig: {{`vector.dimensions`: {dimension}, "
            "`vector.similarity_function`: 'cosine'}}"
        )

        try:
            await self._apply_entity_label(neo4j_client)
            await self._execute_query(neo4j_client, index_cypher)
            logger.info(
                "Vector index 'entity_embedding_index' ensured (dim=%d)", dimension
            )
        except Exception as exc:
            logger.warning(
                "Could not create vector index (may require Neo4j 5.x+): %s", exc
            )

    async def _execute_query(
        self,
        neo4j_client: Any,
        cypher: str,
        params: dict | None = None,
    ) -> list[dict]:
        if hasattr(neo4j_client, "execute_query") and not hasattr(
            neo4j_client,
            "session",
        ):
            return await neo4j_client.execute_query(cypher, params or {})

        async with neo4j_client.session() as session:
            result = await session.run(cypher, params or {})
            return await result.data()

    def _embedding_source(self, node: dict) -> str:
        search_text = node.get("search_text")
        if search_text:
            return str(search_text)
        return f"{node.get('name', '')}\n{node.get('description', '') or ''}"

    def _task_text(self, task: str, text: str) -> str:
        if self.embedding_profile.startswith("nomic-"):
            return f"{task}: {text}"
        return text

    async def embed_query(self, query: str) -> list[float] | None:
        """
        Generate an embedding for a query string (for hybrid search).

        Args:
            query: The query text to embed.

        Returns:
            The embedding vector, or None on failure.
        """
        return await self._generate_embedding(
            self._task_text("search_query", query)
        )

    async def embed_classification(self, text: str) -> list[float] | None:
        """Generate an embedding for intent classification."""
        return await self._generate_embedding(
            self._task_text("classification", text)
        )
