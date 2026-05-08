import logging
from contextlib import asynccontextmanager

from app.api.booking import router as booking_router

# API routers
from app.api.chat import router as chat_router
from app.api.menu import router as menu_router
from app.api.order import router as order_router
from app.api.staff import router as staff_router
from app.core.config import settings
from app.core.database import engine
from app.core.neo4j_client import Neo4jClient
from app.core.redis_client import redis_client
from app.models.base import Base
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

neo4j_client: Neo4jClient | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global neo4j_client

    logger.info("Starting %s (%s)", settings.APP_NAME, settings.APP_ENV)

    # --- Startup ---
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("PostgreSQL tables ensured.")

    neo4j_client = Neo4jClient(
        uri=settings.NEO4J_URI,
        username=settings.NEO4J_USERNAME,
        password=settings.NEO4J_PASSWORD,
    )
    await neo4j_client.connect()
    await neo4j_client.verify_connectivity()
    logger.info("Neo4j connected.")

    await redis_client.connect()
    logger.info("Redis connected.")

    yield

    # --- Shutdown ---
    if neo4j_client:
        await neo4j_client.close()
        logger.info("Neo4j connection closed.")

    await redis_client.close()
    logger.info("Redis connection closed.")

    await engine.dispose()
    logger.info("PostgreSQL engine disposed.")

    logger.info("Shutdown complete.")


app = FastAPI(
    title=settings.APP_NAME,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API routers
app.include_router(chat_router)
app.include_router(booking_router)
app.include_router(order_router)
app.include_router(menu_router)
app.include_router(staff_router)


@app.get("/health")
async def health_check():
    return {"status": "ok", "env": settings.APP_ENV}
