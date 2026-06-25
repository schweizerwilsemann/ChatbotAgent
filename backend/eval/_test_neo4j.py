import asyncio
from neo4j import AsyncGraphDatabase

async def test():
    driver = AsyncGraphDatabase.driver(
        "bolt://localhost:7687",
        auth=("neo4j", "password")
    )
    try:
        async with driver.session() as session:
            result = await session.run("MATCH (n) RETURN count(n) AS count")
            record = await result.single()
            print(f"Neo4j connected! Node count: {record['count']}")
    except Exception as e:
        print(f"Neo4j connection failed: {e}")
    finally:
        await driver.close()

asyncio.run(test())
