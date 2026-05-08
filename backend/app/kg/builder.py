"""
Knowledge Graph Builder Module.

Provides entity extraction from text via LLM and insertion into Neo4j.
Supports billiards, pickleball, and badminton sports domains.
"""

import json
import logging
from typing import Any

from langchain_core.language_models import BaseChatModel
from langchain_core.messages import HumanMessage, SystemMessage

logger = logging.getLogger(__name__)

VALID_ENTITY_TYPES = frozenset(
    {"Rule", "Technique", "Equipment", "Sport", "Concept", "GameType"}
)

VALID_RELATIONSHIP_TYPES = frozenset(
    {
        "DUNG_DE",  # applies to / relevant for
        "LIEN_QUAN",  # related to
        "LA_LOAI",  # is a type of
        "THUOC",  # belongs to
        "SU_DUNG",  # uses
        "QUY_DINH",  # regulates
    }
)

EXTRACTION_SYSTEM_PROMPT = """You are an expert sports knowledge extraction system.
Your task is to extract entities and relationships from the given text about billiards, pickleball, or badminton.

Entity types (use ONLY these):
- Rule: A specific rule or regulation of a sport
- Technique: A playing technique, skill, or method
- Equipment: Physical equipment used in the sport
- Sport: A sport name (billiards, pickleball, badminton)
- Concept: A general concept, strategy, or idea related to sports
- GameType: A specific game variant (e.g., 8-ball, 9-ball, singles, doubles)

Relationship types (use ONLY these):
- DUNG_DE: Entity applies to or is relevant for another entity
- LIEN_QUAN: Entity is related to another entity
- LA_LOAI: Entity is a type/kind of another entity
- THUOC: Entity belongs to / is part of another entity
- SU_DUNG: Entity uses/employs another entity
- QUY_DINH: Entity regulates/governs another entity

Return a JSON object with exactly this structure:
{
    "entities": [
        {
            "name": "entity name (concise, in the same language as the source text)",
            "type": "one of the entity types above",
            "description": "brief description of the entity",
            "properties": {}
        }
    ],
    "relationships": [
        {
            "source": "source entity name (must match a name in entities list)",
            "target": "target entity name (must match a name in entities list)",
            "type": "one of the relationship types above",
            "properties": {}
        }
    ]
}

IMPORTANT:
- Return ONLY valid JSON, no markdown code fences, no explanations.
- Entity names should be concise and unique within the extraction.
- Every relationship source and target must reference an entity name from the entities list.
- Use Vietnamese entity names if the source text is in Vietnamese.
- Use English entity names if the source text is in English.
"""

EXTRACTION_USER_PROMPT = """Extract all sports-related entities and relationships from the following text.
Source: {source}
Sport context: {sport}

Text:
{text}

Return ONLY the JSON object:"""


class KnowledgeGraphBuilder:
    """Builds a knowledge graph in Neo4j from unstructured text using LLM extraction."""

    def __init__(self, neo4j_client: Any, llm: BaseChatModel) -> None:
        """
        Initialize the Knowledge Graph Builder.

        Args:
            neo4j_client: A Neo4j async driver or session object with execute_query support.
            llm: A LangChain chat model instance for entity extraction.
        """
        self.neo4j = neo4j_client
        self.llm = llm

    async def ensure_constraints(self) -> None:
        """Create uniqueness constraints and indexes in Neo4j."""
        constraints = [
            ("CREATE CONSTRAINT IF NOT EXISTS FOR (n:Rule) REQUIRE n.name IS UNIQUE"),
            (
                "CREATE CONSTRAINT IF NOT EXISTS "
                "FOR (n:Technique) REQUIRE n.name IS UNIQUE"
            ),
            (
                "CREATE CONSTRAINT IF NOT EXISTS "
                "FOR (n:Equipment) REQUIRE n.name IS UNIQUE"
            ),
            ("CREATE CONSTRAINT IF NOT EXISTS FOR (n:Sport) REQUIRE n.name IS UNIQUE"),
            (
                "CREATE CONSTRAINT IF NOT EXISTS "
                "FOR (n:Concept) REQUIRE n.name IS UNIQUE"
            ),
            (
                "CREATE CONSTRAINT IF NOT EXISTS "
                "FOR (n:GameType) REQUIRE n.name IS UNIQUE"
            ),
        ]

        indexes = [
            "CREATE INDEX IF NOT EXISTS FOR (n:Rule) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Technique) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Equipment) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Sport) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:Concept) ON (n.name)",
            "CREATE INDEX IF NOT EXISTS FOR (n:GameType) ON (n.name)",
            "CREATE FULLTEXT INDEX IF NOT EXISTS entity_fulltext "
            "FOR (n:Rule|Technique|Equipment|Sport|Concept|GameType) "
            "ON EACH [n.name, n.description]",
        ]

        async with self.neo4j.session() as session:
            for constraint in constraints:
                try:
                    await session.run(constraint)
                    logger.info("Created constraint: %s", constraint[:80])
                except Exception as exc:
                    logger.warning("Constraint creation issue: %s", exc)

            for index in indexes:
                try:
                    await session.run(index)
                    logger.info("Created index: %s", index[:80])
                except Exception as exc:
                    logger.warning("Index creation issue: %s", exc)

    async def extract_entities(
        self, text: str, source: str = "unknown", sport: str = "general"
    ) -> dict:
        """
        Extract entities and relationships from text using LLM.

        Args:
            text: The source text to extract entities from.
            source: The source identifier (URL, filename, etc.).
            sport: The sport context (billiards, pickleball, badminton).

        Returns:
            A dict with 'entities' and 'relationships' lists.
        """
        messages = [
            SystemMessage(content=EXTRACTION_SYSTEM_PROMPT),
            HumanMessage(
                content=EXTRACTION_USER_PROMPT.format(
                    source=source,
                    sport=sport,
                    text=text[:4000],
                )
            ),
        ]

        try:
            response = await self.llm.ainvoke(messages)
            content = response.content.strip()

            # Strip markdown code fences if present
            if content.startswith("```"):
                first_newline = content.index("\n")
                content = content[first_newline + 1 :]
            if content.endswith("```"):
                content = content[:-3].rstrip()

            parsed = json.loads(content)

            # Validate structure
            entities = parsed.get("entities", [])
            relationships = parsed.get("relationships", [])

            # Validate entity types
            valid_entities = []
            entity_names = set()
            for entity in entities:
                if entity.get("type") not in VALID_ENTITY_TYPES:
                    logger.warning(
                        "Skipping entity with invalid type: %s", entity.get("type")
                    )
                    continue
                if not entity.get("name"):
                    continue
                entity["name"] = entity["name"].strip()
                entity["description"] = entity.get("description", "").strip()
                entity["properties"] = entity.get("properties", {})
                entity_names.add(entity["name"])
                valid_entities.append(entity)

            # Validate relationships
            valid_relationships = []
            for rel in relationships:
                if rel.get("type") not in VALID_RELATIONSHIP_TYPES:
                    logger.warning(
                        "Skipping relationship with invalid type: %s", rel.get("type")
                    )
                    continue
                if (
                    rel.get("source") not in entity_names
                    or rel.get("target") not in entity_names
                ):
                    logger.warning(
                        "Skipping relationship with unknown source/target: %s -> %s",
                        rel.get("source"),
                        rel.get("target"),
                    )
                    continue
                rel["properties"] = rel.get("properties", {})
                valid_relationships.append(rel)

            logger.info(
                "Extracted %d entities and %d relationships from text (source=%s)",
                len(valid_entities),
                len(valid_relationships),
                source,
            )
            return {"entities": valid_entities, "relationships": valid_relationships}

        except json.JSONDecodeError as exc:
            logger.error("Failed to parse LLM extraction output as JSON: %s", exc)
            return {"entities": [], "relationships": []}
        except Exception as exc:
            logger.error("Entity extraction failed: %s", exc)
            return {"entities": [], "relationships": []}

    async def insert_entities(
        self, entities_data: dict, source: str = "unknown"
    ) -> None:
        """
        Insert extracted entities and relationships into Neo4j.

        Args:
            entities_data: Dict with 'entities' and 'relationships' lists.
            source: The source identifier for provenance tracking.
        """
        entities = entities_data.get("entities", [])
        relationships = entities_data.get("relationships", [])

        if not entities:
            logger.warning("No entities to insert for source=%s", source)
            return

        async with self.neo4j.session() as session:
            # Insert entities as nodes
            for entity in entities:
                entity_type = entity["type"]
                entity_name = entity["name"]
                description = entity.get("description", "")
                properties = entity.get("properties", {})

                query = (
                    f"MERGE (n:{entity_type} {{name: $name}}) "
                    f"SET n.description = $description, "
                    f"n.source = $source, "
                    f"n.updated_at = datetime() "
                    f"SET n += $properties "
                    f"RETURN n.name AS name"
                )

                try:
                    await session.run(
                        query,
                        name=entity_name,
                        description=description,
                        source=source,
                        properties=properties,
                    )
                except Exception as exc:
                    logger.error("Failed to insert entity '%s': %s", entity_name, exc)

            # Insert relationships
            for rel in relationships:
                source_name = rel["source"]
                target_name = rel["target"]
                rel_type = rel["type"]
                properties = rel.get("properties", {})

                # Find the entity types for source and target
                source_entity = next(
                    (e for e in entities if e["name"] == source_name), None
                )
                target_entity = next(
                    (e for e in entities if e["name"] == target_name), None
                )

                if not source_entity or not target_entity:
                    continue

                query = (
                    f"MATCH (a:{source_entity['type']} {{name: $source_name}}) "
                    f"MATCH (b:{target_entity['type']} {{name: $target_name}}) "
                    f"MERGE (a)-[r:{rel_type}]->(b) "
                    f"SET r += $properties, "
                    f"r.source = $source, "
                    f"r.updated_at = datetime() "
                    f"RETURN type(r) AS rel_type"
                )

                try:
                    await session.run(
                        query,
                        source_name=source_name,
                        target_name=target_name,
                        properties=properties,
                        source=source,
                    )
                except Exception as exc:
                    logger.error(
                        "Failed to insert relationship %s -[%s]-> %s: %s",
                        source_name,
                        rel_type,
                        target_name,
                        exc,
                    )

        logger.info(
            "Inserted %d entities and %d relationships from source=%s",
            len(entities),
            len(relationships),
            source,
        )

    async def build_from_text(
        self, text: str, source: str, sport: str = "general"
    ) -> dict:
        """
        Full pipeline: extract entities from text, then insert into Neo4j.

        Args:
            text: The source text.
            source: The source identifier (URL, filename, etc.).
            sport: The sport context.

        Returns:
            The extracted entities dict for downstream use.
        """
        logger.info("Building knowledge graph from source=%s, sport=%s", source, sport)

        # Step 1: Ensure constraints and indexes exist
        await self.ensure_constraints()

        # Step 2: Extract entities
        entities_data = await self.extract_entities(text, source=source, sport=sport)

        if not entities_data["entities"]:
            logger.warning("No entities extracted from source=%s", source)
            return entities_data

        # Step 3: Insert into Neo4j
        await self.insert_entities(entities_data, source=source)

        logger.info(
            "Knowledge graph build complete for source=%s: "
            "%d entities, %d relationships",
            source,
            len(entities_data["entities"]),
            len(entities_data["relationships"]),
        )
        return entities_data
