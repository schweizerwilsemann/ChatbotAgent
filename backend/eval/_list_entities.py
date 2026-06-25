import asyncio
from eval.neo4j_helper import connect_neo4j

async def main():
    driver = await connect_neo4j()
    
    async with driver.session() as session:
        result = await session.run("""
            MATCH (n) 
            WHERE n:Rule OR n:Technique OR n:Equipment OR n:Sport OR n:Concept OR n:GameType
            RETURN n.name AS name, labels(n)[0] AS type
            ORDER BY n.name
        """)
        entities = [(r["name"], r["type"]) async for r in result]
    
    await driver.close()
    
    by_type = {}
    for name, etype in entities:
        by_type.setdefault(etype, []).append(name)
    
    for etype, names in sorted(by_type.items()):
        print(f"\n=== {etype} ({len(names)}) ===")
        for n in names:
            print(f"  {n}")

asyncio.run(main())
