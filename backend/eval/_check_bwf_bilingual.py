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
            RETURN n.name AS name, n.name_vi AS name_vi, 
                   n.search_text AS search_text
            ORDER BY n.name
        """)
        print("=== BWF Rules Bilingual Fields ===")
        async for r in result:
            name_vi = r['name_vi'] or 'N/A'
            search = (r['search_text'] or '')[:100]
            print(f"  {r['name']}")
            print(f"    name_vi: {name_vi}")
            print(f"    search: {search}...")
    await driver.close()

asyncio.run(main())
