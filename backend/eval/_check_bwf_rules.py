import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from eval.neo4j_helper import connect_neo4j

async def main():
    driver = await connect_neo4j()
    async with driver.session() as session:
        result = await session.run("""
            MATCH (n:Rule)
            WHERE n.source CONTAINS 'bwf'
            OPTIONAL MATCH (n)-[r]-(related)
            RETURN n.name AS rule, type(r) AS rel, related.name AS related
            ORDER BY n.name
            LIMIT 20
        """)
        print("=== BWF Rules & Relationships ===")
        async for r in result:
            rel = r['rel'] or 'NO RELATIONSHIP'
            related = r['related'] or 'N/A'
            print(f"  {r['rule']} --{rel}--> {related}")
    await driver.close()

asyncio.run(main())
