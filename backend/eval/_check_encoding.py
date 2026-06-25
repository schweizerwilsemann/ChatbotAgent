import asyncio
from neo4j import AsyncGraphDatabase

async def check():
    driver = AsyncGraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "password"))
    async with driver.session() as session:
        # Check Vietnamese text in search_text field
        result = await session.run("""
            MATCH (n) 
            WHERE n.search_text IS NOT NULL 
            RETURN n.name AS name, n.name_vi AS name_vi, 
                   substring(n.search_text, 0, 100) AS search_preview
            LIMIT 10
        """)
        print("=== Sample nodes with bilingual fields ===")
        async for r in result:
            print(f"Name: {r['name']}")
            print(f"  name_vi: {r['name_vi']}")
            print(f"  search_text: {r['search_preview']}")
            print()
        
        # Check if Smash node exists with correct encoding
        result2 = await session.run("""
            MATCH (n:Technique) 
            WHERE toLower(n.name) CONTAINS 'smash' 
            RETURN n.name AS name, n.name_vi AS name_vi, n.description AS desc
        """)
        print("=== Smash nodes ===")
        async for r in result2:
            print(f"  {r['name']} | {r['name_vi']} | {r['desc'][:80] if r['desc'] else 'N/A'}")
        
        # Check Grip node
        result3 = await session.run("""
            MATCH (n:Technique) 
            WHERE toLower(n.name) CONTAINS 'grip' 
            RETURN n.name AS name, n.name_vi AS name_vi
        """)
        print("\n=== Grip nodes ===")
        async for r in result3:
            print(f"  {r['name']} | {r['name_vi']}")
    await driver.close()

asyncio.run(check())
