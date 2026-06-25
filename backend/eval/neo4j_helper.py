"""Neo4j connection helper with AuraDB → Local fallback."""

import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from neo4j import AsyncGraphDatabase

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

logger = logging.getLogger(__name__)

NEO4J_CONFIGS = [
    {
        "name": "AuraDB",
        "uri": os.getenv("NEO4J_URI", ""),
        "user": os.getenv("NEO4J_USERNAME", ""),
        "password": os.getenv("NEO4J_PASSWORD", ""),
    },
    {
        "name": "Local Docker",
        "uri": "bolt://localhost:7687",
        "user": "neo4j",
        "password": "password",
    },
]


async def connect_neo4j():
    """Try AuraDB first, fallback to local Docker."""
    for cfg in NEO4J_CONFIGS:
        if not cfg["uri"]:
            continue
        try:
            driver = AsyncGraphDatabase.driver(
                cfg["uri"], auth=(cfg["user"], cfg["password"])
            )
            async with driver.session() as session:
                result = await session.run("MATCH (n) RETURN count(n) AS c")
                record = await result.single()
                count = record["c"]
                logger.info("Connected to %s: %d nodes", cfg["name"], count)
                return driver
        except Exception as exc:
            logger.warning("%s failed: %s", cfg["name"], exc)
    raise RuntimeError("No Neo4j instance available")
