import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from eval.neo4j_helper import connect_neo4j
from app.kg.bilingual import sync_bilingual_fields

async def main():
    driver = await connect_neo4j()
    updated = await sync_bilingual_fields(driver)
    print(f"Updated {updated} nodes with bilingual fields")
    await driver.close()

asyncio.run(main())
