import asyncio
from eval.neo4j_helper import connect_neo4j

async def check():
    try:
        driver = await connect_neo4j()
        async with driver.session() as session:
            result = await session.run("MATCH (n) RETURN count(n) AS count")
            record = await result.single()
            count = record["count"]

            result2 = await session.run("MATCH (n) WHERE n.embedding IS NOT NULL RETURN count(n) AS emb_count")
            record2 = await result2.single()
            emb = record2["emb_count"]

            print(f"[OK] Neo4j: {count} nodes, {emb} embeddings")
        await driver.close()
    except Exception as e:
        print(f"[FAIL] Neo4j: {e}")

asyncio.run(check())
