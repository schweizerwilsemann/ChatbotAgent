import logging

from neo4j import AsyncDriver, AsyncGraphDatabase

logger = logging.getLogger(__name__)


class Neo4jClient:
    def __init__(self, uri: str, username: str, password: str) -> None:
        self._uri = uri
        self._username = username
        self._password = password
        self._driver: AsyncDriver | None = None

    async def connect(self) -> None:
        self._driver = AsyncGraphDatabase.driver(
            self._uri,
            auth=(self._username, self._password),
        )
        logger.info("Neo4j driver created for %s", self._uri)

    async def close(self) -> None:
        if self._driver:
            await self._driver.close()
            self._driver = None
            logger.info("Neo4j driver closed.")

    async def verify_connectivity(self) -> None:
        if not self._driver:
            raise RuntimeError("Neo4j driver is not initialised. Call connect() first.")
        await self._driver.verify_connectivity()
        logger.info("Neo4j connectivity verified.")

    async def execute_query(self, query: str, params: dict | None = None) -> list[dict]:
        if not self._driver:
            raise RuntimeError("Neo4j driver is not initialised. Call connect() first.")
        async with self._driver.session() as session:
            result = await session.run(query, params or {})
            records = await result.data()
            return records
