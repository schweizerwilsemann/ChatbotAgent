"""
Step 04: Generate and store embeddings for knowledge graph nodes.

Connects to Neo4j, reads all nodes, generates embeddings for their
names and descriptions, and stores them back as node properties.
"""

import asyncio
import logging
import os
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.kg.embeddings import NodeEmbedder

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def get_neo4j_client():
    """
    Create and return a Neo4j async driver.

    Reads connection details from environment variables:
    - NEO4J_URI (default: bolt://localhost:7687)
    - NEO4J_USER (default: neo4j)
    - NEO4J_PASSWORD (default: password)

    Returns:
        A Neo4j async driver instance.
    """
    uri = os.environ.get("NEO4J_URI", "neo4j+s://localhost:7687")
    user = os.environ.get("NEO4J_USERNAME", "neo4j")
    password = os.environ.get("NEO4J_PASSWORD", "password")

    try:
        from neo4j import AsyncGraphDatabase

        driver = AsyncGraphDatabase.driver(uri, auth=(user, password))
        logger.info("Created Neo4j driver for %s (user=%s)", uri, user)
        return driver
    except ImportError:
        logger.error("neo4j package not installed. Install with: pip install neo4j")
        raise
    except Exception as exc:
        logger.error("Failed to create Neo4j driver: %s", exc)
        raise


async def verify_connection(driver) -> bool:
    """
    Verify that the Neo4j connection is working.

    Args:
        driver: The Neo4j async driver.

    Returns:
        True if connection is successful, False otherwise.
    """
    try:
        async with driver.session() as session:
            result = await session.run("RETURN 1 AS num")
            record = await result.single()
            if record and record["num"] == 1:
                logger.info("Neo4j connection verified successfully")
                return True
        return False
    except Exception as exc:
        logger.error("Neo4j connection verification failed: %s", exc)
        return False


async def fetch_all_nodes(driver) -> list[dict]:
    """
    Fetch all entity nodes from Neo4j.

    Args:
        driver: The Neo4j async driver.

    Returns:
        List of node dicts with 'name', 'type', and 'description'.
    """
    node_types = ["Rule", "Technique", "Equipment", "Sport", "Concept", "GameType"]
    all_nodes: list[dict] = []

    async with driver.session() as session:
        for node_type in node_types:
            cypher = (
                f"MATCH (n:{node_type}) "
                f"RETURN n.name AS name, "
                f"       '{node_type}' AS type, "
                f"       n.description AS description "
                f"ORDER BY n.name"
            )

            try:
                result = await session.run(cypher)
                records = await result.data()

                for record in records:
                    name = record.get("name", "")
                    if name:
                        all_nodes.append(
                            {
                                "name": name,
                                "type": record.get("type", node_type),
                                "description": record.get("description", "") or "",
                            }
                        )

                logger.info("Fetched %d %s nodes", len(records), node_type)
            except Exception as exc:
                logger.error("Failed to fetch %s nodes: %s", node_type, exc)

    logger.info("Total nodes fetched: %d", len(all_nodes))
    return all_nodes


async def main() -> None:
    """Generate and store embeddings for all knowledge graph nodes."""
    logger.info("Starting node embedding pipeline")

    # Configuration from environment
    embedding_api_url = os.environ.get(
        "EMBEDDING_API_URL", "http://localhost:11434/api/embeddings"
    )
    embedding_model = os.environ.get("EMBEDDING_MODEL", "nomic-embed-text")
    batch_size = int(os.environ.get("EMBEDDING_BATCH_SIZE", "16"))

    logger.info("Embedding API: %s", embedding_api_url)
    logger.info("Embedding model: %s", embedding_model)
    logger.info("Batch size: %d", batch_size)

    # Create embedder
    embedder = NodeEmbedder(
        embedding_api_url=embedding_api_url,
        model_name=embedding_model,
        batch_size=batch_size,
        max_concurrent=4,
    )

    # Connect to Neo4j
    try:
        driver = get_neo4j_client()
    except Exception as exc:
        logger.error("Cannot connect to Neo4j: %s", exc)
        logger.info(
            "Make sure Neo4j is running and set the following environment variables:\n"
            "  NEO4J_URI=bolt://localhost:7687\n"
            "  NEO4J_USER=neo4j\n"
            "  NEO4J_PASSWORD=your_password"
        )
        return

    try:
        # Verify connection
        connected = await verify_connection(driver)
        if not connected:
            logger.error("Cannot verify Neo4j connection. Aborting.")
            return

        # Fetch all nodes
        nodes = await fetch_all_nodes(driver)
        if not nodes:
            logger.warning("No nodes found in Neo4j. Run 03_build_graph.py first.")
            return

        # Generate and store embeddings
        logger.info("Generating embeddings for %d nodes...", len(nodes))
        stored_count = await embedder.embed_and_store(driver, nodes)

        # Verify embeddings were stored
        logger.info("Verifying stored embeddings...")
        async with driver.session() as session:
            result = await session.run(
                "MATCH (n) WHERE n.embedding IS NOT NULL "
                "RETURN labels(n)[0] AS type, count(n) AS count "
                "ORDER BY count DESC"
            )
            records = await result.data()

            total_embedded = 0
            for record in records:
                logger.info(
                    "  %s: %d nodes with embeddings", record["type"], record["count"]
                )
                total_embedded += record["count"]

        logger.info("=" * 60)
        logger.info("Node embedding pipeline complete!")
        logger.info("  Total nodes processed: %d", len(nodes))
        logger.info("  Embeddings stored: %d", stored_count)
        logger.info("  Verified in graph: %d", total_embedded)
        logger.info("=" * 60)

    finally:
        await driver.close()
        logger.info("Neo4j connection closed")


if __name__ == "__main__":
    asyncio.run(main())
