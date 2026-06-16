"""
Step 05: Enrich existing Neo4j knowledge nodes with bilingual search fields.

This step is safe to run after the graph has already been built. It does not
scrape or extract data again; it only sets name_vi, aliases_vi, aliases_en and
search_text so Vietnamese questions can retrieve the mostly-English corpus.
"""

import asyncio
import logging
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_ROOT))
load_dotenv(BACKEND_ROOT / ".env")

from app.kg.bilingual import bilingual_fulltext_index_cypher, sync_bilingual_fields

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def get_neo4j_client():
    uri = os.environ.get("NEO4J_URI", "neo4j+s://localhost:7687")
    user = os.environ.get("NEO4J_USERNAME", "neo4j")
    password = os.environ.get("NEO4J_PASSWORD", "password")

    from neo4j import AsyncGraphDatabase

    driver = AsyncGraphDatabase.driver(uri, auth=(user, password))
    logger.info("Created Neo4j driver for %s (user=%s)", uri, user)
    return driver


async def main() -> None:
    driver = get_neo4j_client()
    try:
        await driver.verify_connectivity()
        async with driver.session() as session:
            await session.run(bilingual_fulltext_index_cypher())

        updated = await sync_bilingual_fields(driver)
        logger.info("Bilingual KG enrichment complete: updated=%d", updated)
        logger.info(
            "Run 04_embed_nodes.py afterwards or restart backend with "
            "KG_AUTO_EMBED_ON_STARTUP=true to refresh embeddings from search_text."
        )
    finally:
        await driver.close()


if __name__ == "__main__":
    asyncio.run(main())
