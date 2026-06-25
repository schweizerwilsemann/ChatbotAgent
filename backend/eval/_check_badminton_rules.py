import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from eval.neo4j_helper import connect_neo4j

async def main():
    driver = await connect_neo4j()
    async with driver.session() as session:
        result = await session.run("""
            MATCH (n:Rule)-[:THUOC]->(s:Sport {name: "badminton"})
            RETURN n.name AS name, n.name_vi AS name_vi
            UNION
            MATCH (n:Rule)-[:THUOC]->(s:Sport {name: "Badminton"})
            RETURN n.name AS name, n.name_vi AS name_vi
            ORDER BY name
        """)
        print("=== Badminton Rules ===")
        async for r in result:
            print(f"  {r['name']} | {r['name_vi'] or 'N/A'}")
    await driver.close()

asyncio.run(main())
