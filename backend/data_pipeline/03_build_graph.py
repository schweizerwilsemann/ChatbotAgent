"""
Step 03: Build the Neo4j knowledge graph from extracted entities.

Reads extracted entity JSON files from extracted/, connects to Neo4j,
creates all nodes and relationships with indexes, constraints, and
duplicate checking.
"""

import asyncio
import json
import logging
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

# Load .env before any other imports that read environment variables
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.kg.builder import (
    VALID_ENTITY_TYPES,
    VALID_RELATIONSHIP_TYPES,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

EXTRACTED_DIR = Path(__file__).resolve().parent / "extracted"


def load_extracted_files() -> list[Path]:
    """
    Load all extracted entity JSON files.

    Returns:
        List of Path objects for each JSON file in extracted/.
    """
    if not EXTRACTED_DIR.exists():
        logger.error("Extracted directory does not exist: %s", EXTRACTED_DIR)
        return []

    json_files = sorted(EXTRACTED_DIR.glob("extracted_*.json"))
    logger.info("Found %d extracted data files", len(json_files))
    return json_files


def load_extracted_data(filepath: Path) -> list[dict]:
    """
    Load extracted entity data from a JSON file.

    Args:
        filepath: Path to the extracted JSON file.

    Returns:
        List of extraction result dicts.
    """
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = json.load(f)

        extractions = content.get("extractions", [])
        logger.info(
            "Loaded %d extractions from %s (total entities: %d)",
            len(extractions),
            filepath.name,
            content.get("total_entities", 0),
        )
        return extractions
    except Exception as exc:
        logger.error("Failed to load extracted data from %s: %s", filepath, exc)
        return []


def deduplicate_entities(all_extractions: list[dict]) -> tuple[list[dict], list[dict]]:
    """
    Deduplicate entities and relationships across all extractions.

    Args:
        all_extractions: List of extraction result dicts.

    Returns:
        Tuple of (deduplicated entities list, deduplicated relationships list).
    """
    seen_entities: dict[str, dict] = {}
    seen_relationships: set[tuple[str, str, str]] = set()
    deduped_relationships: list[dict] = []

    for extraction in all_extractions:
        entities = extraction.get("entities", [])
        relationships = extraction.get("relationships", [])
        source = extraction.get("chunk_source", "unknown")

        for entity in entities:
            name = entity.get("name", "").strip()
            entity_type = entity.get("type", "")

            if not name or entity_type not in VALID_ENTITY_TYPES:
                continue

            key = f"{entity_type}:{name}"
            if key not in seen_entities:
                seen_entities[key] = {
                    "name": name,
                    "type": entity_type,
                    "description": entity.get("description", ""),
                    "properties": entity.get("properties", {}),
                    "sources": [source],
                }
            else:
                # Merge descriptions if different
                existing = seen_entities[key]
                new_desc = entity.get("description", "").strip()
                if new_desc and new_desc not in existing["description"]:
                    if existing["description"]:
                        existing["description"] += " | " + new_desc
                    else:
                        existing["description"] = new_desc
                if source not in existing["sources"]:
                    existing["sources"].append(source)

        for rel in relationships:
            rel_type = rel.get("type", "")
            source_name = rel.get("source", "").strip()
            target_name = rel.get("target", "").strip()

            if not source_name or not target_name:
                continue
            if rel_type not in VALID_RELATIONSHIP_TYPES:
                continue

            rel_key = (source_name, rel_type, target_name)
            if rel_key not in seen_relationships:
                seen_relationships.add(rel_key)
                deduped_relationships.append(
                    {
                        "source": source_name,
                        "target": target_name,
                        "type": rel_type,
                        "properties": rel.get("properties", {}),
                    }
                )

    entities_list = list(seen_entities.values())
    logger.info(
        "Deduplication: %d unique entities, %d unique relationships",
        len(entities_list),
        len(deduped_relationships),
    )
    return entities_list, deduped_relationships


def get_neo4j_client():
    """
    Create and return a Neo4j async driver.

    Reads connection details from environment variables:
    - NEO4J_URI (default: bolt://localhost:7687)
    - NEO4J_USER (default: neo4j)
    - NEO4J_PASSWORD (default: password)

    Returns:
        A Neo4j async driver instance.

    Raises:
        ImportError: If neo4j package is not installed.
        Exception: If connection fails.
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


async def insert_all_entities(
    driver,
    entities: list[dict],
    relationships: list[dict],
) -> tuple[int, int]:
    """
    Insert all entities and relationships into Neo4j.

    Args:
        driver: The Neo4j async driver.
        entities: List of deduplicated entity dicts.
        relationships: List of deduplicated relationship dicts.

    Returns:
        Tuple of (entities inserted count, relationships inserted count).
    """
    entities_inserted = 0
    relationships_inserted = 0

    async with driver.session() as session:
        # Step 1: Create constraints and indexes
        logger.info("Creating constraints and indexes...")
        constraints = [
            "CREATE CONSTRAINT IF NOT EXISTS FOR (n:Rule) REQUIRE n.name IS UNIQUE",
            "CREATE CONSTRAINT IF NOT EXISTS FOR (n:Technique) REQUIRE n.name IS UNIQUE",
            "CREATE CONSTRAINT IF NOT EXISTS FOR (n:Equipment) REQUIRE n.name IS UNIQUE",
            "CREATE CONSTRAINT IF NOT EXISTS FOR (n:Sport) REQUIRE n.name IS UNIQUE",
            "CREATE CONSTRAINT IF NOT EXISTS FOR (n:Concept) REQUIRE n.name IS UNIQUE",
            "CREATE CONSTRAINT IF NOT EXISTS FOR (n:GameType) REQUIRE n.name IS UNIQUE",
        ]

        for constraint in constraints:
            try:
                await session.run(constraint)
            except Exception as exc:
                logger.warning("Constraint issue (may already exist): %s", exc)

        indexes = [
            "CREATE INDEX IF NOT EXISTS FOR (n:Rule) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Technique) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Equipment) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Sport) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Concept) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:GameType) ON (n.name)",
            (
                "CREATE FULLTEXT INDEX IF NOT EXISTS entity_fulltext "
                "FOR (n:Rule|Technique|Equipment|Sport|Concept|GameType) "
                "ON EACH [n.name, n.description]"
            ),
        ]

        for index in indexes:
            try:
                await session.run(index)
            except Exception as exc:
                logger.warning("Index issue (may already exist): %s", exc)

        logger.info("Constraints and indexes created")

        # Step 2: Insert entities
        logger.info("Inserting %d entities...", len(entities))
        for i, entity in enumerate(entities):
            entity_type = entity["type"]
            entity_name = entity["name"]
            description = entity.get("description", "")
            properties = entity.get("properties", {})
            sources = entity.get("sources", [])

            cypher = (
                f"MERGE (n:{entity_type} {{name: $name}}) "
                f"ON CREATE SET "
                f"  n.description = $description, "
                f"  n.source = $source, "
                f"  n.created_at = datetime(), "
                f"  n.updated_at = datetime() "
                f"ON MATCH SET "
                f"  n.description = CASE "
                f"    WHEN n.description IS NULL OR n.description = '' "
                f"    THEN $description "
                f"    ELSE n.description END, "
                f"  n.updated_at = datetime() "
                f"SET n += $properties "
                f"RETURN n.name AS name"
            )

            try:
                result = await session.run(
                    cypher,
                    name=entity_name,
                    description=description,
                    source=", ".join(sources) if sources else "unknown",
                    properties=properties,
                )
                record = await result.single()
                if record:
                    entities_inserted += 1
            except Exception as exc:
                logger.error(
                    "Failed to insert entity '%s' (%s): %s",
                    entity_name,
                    entity_type,
                    exc,
                )

            if (i + 1) % 100 == 0:
                logger.info("  Inserted %d/%d entities...", i + 1, len(entities))

        logger.info("Entities inserted: %d/%d", entities_inserted, len(entities))

        # Step 3: Insert relationships
        logger.info("Inserting %d relationships...", len(relationships))
        entity_type_map = {e["name"]: e["type"] for e in entities}

        for i, rel in enumerate(relationships):
            source_name = rel["source"]
            target_name = rel["target"]
            rel_type = rel["type"]
            properties = rel.get("properties", {})

            # Look up entity types for proper label matching
            source_type = entity_type_map.get(source_name)
            target_type = entity_type_map.get(target_name)

            if not source_type or not target_type:
                logger.debug(
                    "Skipping relationship: unknown entity type for %s -> %s",
                    source_name,
                    target_name,
                )
                continue

            # Build Cypher with dynamic labels
            cypher = (
                f"MATCH (a:{source_type} {{name: $source_name}}) "
                f"MATCH (b:{target_type} {{name: $target_name}}) "
                f"MERGE (a)-[r:{rel_type}]->(b) "
                f"SET r += $properties, "
                f"    r.source = 'pipeline', "
                f"    r.updated_at = datetime() "
                f"RETURN type(r) AS rel_type"
            )

            try:
                result = await session.run(
                    cypher,
                    source_name=source_name,
                    target_name=target_name,
                    properties=properties,
                )
                record = await result.single()
                if record:
                    relationships_inserted += 1
            except Exception as exc:
                logger.error(
                    "Failed to insert relationship %s -[%s]-> %s: %s",
                    source_name,
                    rel_type,
                    target_name,
                    exc,
                )

            if (i + 1) % 100 == 0:
                logger.info(
                    "  Inserted %d/%d relationships...", i + 1, len(relationships)
                )

        logger.info(
            "Relationships inserted: %d/%d",
            relationships_inserted,
            len(relationships),
        )

    return entities_inserted, relationships_inserted


async def main() -> None:
    """Build the Neo4j knowledge graph from extracted entity files."""
    logger.info("Starting knowledge graph build pipeline")
    logger.info("Extracted data directory: %s", EXTRACTED_DIR)

    # Load extracted data files
    extracted_files = load_extracted_files()
    if not extracted_files:
        logger.error("No extracted data files found. Run 02_extract_entities.py first.")
        return

    # Load all extractions
    all_extractions: list[dict] = []
    for filepath in extracted_files:
        extractions = load_extracted_data(filepath)
        all_extractions.extend(extractions)

    if not all_extractions:
        logger.error("No extractions found in any file.")
        return

    logger.info("Loaded %d total extraction chunks", len(all_extractions))

    # Deduplicate entities and relationships
    entities, relationships = deduplicate_entities(all_extractions)

    if not entities:
        logger.error("No valid entities found after deduplication.")
        return

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

        # Insert all entities and relationships
        entities_count, rels_count = await insert_all_entities(
            driver, entities, relationships
        )

        logger.info("=" * 60)
        logger.info("Knowledge graph build complete!")
        logger.info("  Entities inserted: %d", entities_count)
        logger.info("  Relationships inserted: %d", rels_count)
        logger.info("=" * 60)

    finally:
        await driver.close()
        logger.info("Neo4j connection closed")


if __name__ == "__main__":
    asyncio.run(main())
