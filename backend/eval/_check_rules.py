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
            RETURN n.name AS name, n.name_vi AS name_vi, n.source AS source
            ORDER BY name
            LIMIT 30
        """)
        print("=== All Rules (sample) ===")
        async for r in result:
            print(f"  [{r['source'] or 'N/A'}] {r['name']} | {r['name_vi'] or 'N/A'}")
    await driver.close()

asyncio.run(main())
