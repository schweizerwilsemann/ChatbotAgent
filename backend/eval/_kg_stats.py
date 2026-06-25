import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from eval.neo4j_helper import connect_neo4j

async def main():
    driver = await connect_neo4j()
    
    async with driver.session() as session:
        # Count by type
        result = await session.run("""
            MATCH (n) 
            WHERE n:Rule OR n:Technique OR n:Equipment OR n:Sport OR n:Concept OR n:GameType
            RETURN labels(n)[0] AS type, count(n) AS cnt 
            ORDER BY cnt DESC
        """)
        print("=== Current KG Stats ===")
        total = 0
        async for r in result:
            print(f"  {r['type']}: {r['cnt']}")
            total += r['cnt']
        print(f"  TOTAL: {total}")
        
        # Count relationships
        result2 = await session.run("MATCH ()-[r]->() RETURN type(r) AS type, count(r) AS cnt ORDER BY cnt DESC")
        print("\n=== Relationships ===")
        async for r in result2:
            print(f"  {r['type']}: {r['cnt']}")
        
        # Find entities WITHOUT name_vi (missing bilingual)
        result3 = await session.run("""
            MATCH (n) 
            WHERE n:Rule OR n:Technique OR n:Equipment OR n:Sport OR n:Concept OR n:GameType
              AND (n.name_vi IS NULL OR n.name_vi = '')
            RETURN n.name AS name, labels(n)[0] AS type
            ORDER BY type, name
            LIMIT 30
        """)
        print("\n=== Entities WITHOUT Vietnamese name (sample) ===")
        async for r in result3:
            print(f"  [{r['type']}] {r['name']}")
    
    await driver.close()

asyncio.run(main())
