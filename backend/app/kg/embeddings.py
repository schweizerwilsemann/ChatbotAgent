"""
Node Embeddings Module.

Generates and stores vector embeddings for knowledge graph nodes.
Supports external embedding API calls for high-quality embeddings.
"""

import asyncio
import logging
from typing import Any

import httpx

logger = logging.getLogger(__name__)


class NodeEmbedder:
    """Generates and stores embeddings for knowledge graph nodes in Neo4j."""

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
        node_type = node.get("type", "")

        parts = []
        if node_type:
            parts.append(f"[{node_type}]")
        parts.append(name)
        if description and description != name:
            parts.append(description)

        return " ".join(parts)

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

        # Step 1: Create vector index if it doesn't exist
        await self._ensure_vector_index(neo4j_client)

        # Step 2: Generate embeddings
        embeddings = await self.generate_embeddings(nodes)

        # Step 3: Store embeddings in Neo4j
        stored_count = 0
        async with neo4j_client.session() as session:
            for node, embedding in zip(nodes, embeddings):
                if embedding is None:
                    continue

                node_type = node.get("type", "Concept")
                node_name = node.get("name", "")

                if not node_name:
                    continue

                cypher = (
                    f"MATCH (n:{node_type} {{name: $name}}) "
                    f"SET n.embedding = $embedding "
                    f"RETURN n.name AS name"
                )

                try:
                    result = await session.run(
                        cypher, name=node_name, embedding=embedding
                    )
                    record = await result.single()
                    if record:
                        stored_count += 1
                except Exception as exc:
                    logger.error(
                        "Failed to store embedding for '%s': %s", node_name, exc
                    )

        logger.info(
            "Stored embeddings for %d/%d nodes",
            stored_count,
            len(nodes),
        )
        return stored_count

    async def _ensure_vector_index(self, neo4j_client: Any) -> None:
        """
        Ensure the vector index for node embeddings exists in Neo4j.

        Args:
            neo4j_client: A Neo4j async driver or session-compatible object.
        """
        # Determine the embedding dimension from a test embedding
        test_embedding = await self._generate_embedding("test")
        if test_embedding is None:
            logger.error("Cannot determine embedding dimension; API not available")
            return

        dimension = len(test_embedding)
        logger.info("Detected embedding dimension: %d", dimension)

        cypher = (
            "CREATE VECTOR INDEX entity_embedding_index IF NOT EXISTS "
            "FOR (n:Rule|Technique|Equipment|Sport|Concept|GameType) "
            f"ON (n.embedding) "
            f"OPTIONS {{indexConfig: {{`vector.dimensions`: {dimension}, `vector.similarity_function`: 'cosine'}}}}"
        )

        try:
            async with neo4j_client.session() as session:
                await session.run(cypher)
                logger.info(
                    "Vector index 'entity_embedding_index' ensured (dim=%d)", dimension
                )
        except Exception as exc:
            logger.warning(
                "Could not create vector index (may require Neo4j 5.x+): %s", exc
            )

    async def embed_query(self, query: str) -> list[float] | None:
        """
        Generate an embedding for a query string (for hybrid search).

        Args:
            query: The query text to embed.

        Returns:
            The embedding vector, or None on failure.
        """
        return await self._generate_embedding(query)
