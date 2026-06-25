import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from eval.neo4j_helper import connect_neo4j
from app.kg.bilingual import build_bilingual_fields, BILINGUAL_PROFILE

async def main():
    driver = await connect_neo4j()
    
    async with driver.session() as session:
        result = await session.run("""
            MATCH (n) 
            WHERE n:Rule OR n:Technique OR n:Equipment OR n:Sport OR n:Concept OR n:GameType
            RETURN elementId(n) AS node_id, n.name AS name, 
                   labels(n)[0] AS type, n.description AS description
        """)
        nodes = []
        async for r in result:
            nodes.append({
                "node_id": r["node_id"],
                "name": r["name"],
                "type": r["type"],
                "description": r["description"] or "",
            })
    
    print(f"Found {len(nodes)} nodes")
    
    updated = 0
    async with driver.session() as session:
        for node in nodes:
            fields = build_bilingual_fields(node)
            
            await session.run("""
                MATCH (n) WHERE elementId(n) = $node_id
                SET n.name_vi = $name_vi,
                    n.aliases_vi = $aliases_vi,
                    n.aliases_en = $aliases_en,
                    n.search_text = $search_text,
                    n.bilingual_profile = $profile,
                    n.bilingual_updated_at = datetime()
            """, 
                node_id=node["node_id"],
                name_vi=fields["name_vi"],
                aliases_vi=fields["aliases_vi"],
                aliases_en=fields["aliases_en"],
                search_text=fields["search_text"],
                profile=BILINGUAL_PROFILE,
            )
            updated += 1
            
            if updated % 50 == 0:
                print(f"  Updated {updated}/{len(nodes)} nodes...")
    
    print(f"Done! Updated {updated} nodes")

asyncio.run(main())
