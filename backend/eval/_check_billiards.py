import asyncio
from eval.neo4j_helper import connect_neo4j

async def main():
    driver = await connect_neo4j()
    async with driver.session() as session:
        result = await session.run("""
            MATCH (n:Technique) 
            WHERE toLower(n.name) CONTAINS 'bank' 
               OR toLower(n.name) CONTAINS 'safety'
               OR toLower(n.name) CONTAINS 'kick'
               OR toLower(n.name) CONTAINS 'masse'
               OR toLower(n.name) CONTAINS 'defensive'
            RETURN n.name AS name, substring(n.description, 0, 80) AS desc
        """)
        print("=== Billiards defensive techniques ===")
        async for r in result:
            print(f"  {r['name']}: {r['desc'] or 'N/A'}")
    await driver.close()

asyncio.run(main())
