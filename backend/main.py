import logging
from contextlib import asynccontextmanager

from app.agent.agent import VenueAgent
from app.agent.simple_agent import SimpleVenueAgent
from app.agent.tools import (
    book_court,
    call_staff,
    check_schedule,
    order_food,
    query_knowledge,
    recommend_menu,
)
from app.agent.tools.query_faq import set_neo4j_client
from app.api.admin import router as admin_router
from app.api.auth import router as auth_router
from app.api.booking import router as booking_router
from app.api.chat import router as chat_router

# API routers
from app.api.chat import set_chat_service
from app.api.menu import router as menu_router
from app.api.order import router as order_router
from app.api.realtime import router as realtime_router
from app.api.staff import router as staff_router
from app.api.staff_request import router as staff_request_router
from app.core.config import settings
from app.core.database import async_session_factory, engine
from app.core.neo4j_client import Neo4jClient
from app.core.redis_client import redis_client
from app.core.seed import (
    ensure_user_password_column,
    seed_admin_user,
    seed_customer_user,
    seed_default_menu,
    seed_staff_user,
)
from app.kg.embeddings import NodeEmbedder
from app.models.base import Base
from app.services.chat_service import ChatService
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

neo4j_client: Neo4jClient | None = None
chat_service: ChatService | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global neo4j_client, chat_service

    logger.info("Starting %s (%s)", settings.APP_NAME, settings.APP_ENV)

    # --- Startup ---
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("PostgreSQL tables ensured.")
    await ensure_user_password_column(engine)
    async with async_session_factory() as session:
        await seed_admin_user(session)
        await seed_staff_user(session)
        await seed_customer_user(session)
        await seed_default_menu(session)
        await session.commit()

    neo4j_client = Neo4jClient(
        uri=settings.NEO4J_URI,
        username=settings.NEO4J_USERNAME,
        password=settings.NEO4J_PASSWORD,
    )
    try:
        await neo4j_client.connect()
        await neo4j_client.verify_connectivity()
        set_neo4j_client(neo4j_client)
        logger.info("Neo4j connected.")
    except Exception:
        logger.warning("Neo4j unavailable; knowledge tool disabled", exc_info=True)
        await neo4j_client.close()
        neo4j_client = None
        set_neo4j_client(None)

    await redis_client.connect()
    logger.info("Redis ready.")

    try:
        embedder = NodeEmbedder()
        agent = VenueAgent(
            tools=[
                query_knowledge,
                book_court,
                order_food,
                call_staff,
                check_schedule,
                recommend_menu,
            ],
            neo4j_client=neo4j_client,
            embedder=embedder,
        )
    except Exception:
        logger.warning(
            "LLM agent unavailable; using deterministic dev fallback", exc_info=True
        )
        agent = SimpleVenueAgent()
    try:
        await agent.initialize()
    except Exception:
        logger.warning(
            "Agent initialization failed; using deterministic dev fallback",
            exc_info=True,
        )
        agent = SimpleVenueAgent()
        await agent.initialize()
    chat_service = ChatService(agent)
    set_chat_service(chat_service)
    logger.info("Chat service initialized.")

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
app.include_router(auth_router)
app.include_router(chat_router)
app.include_router(booking_router)
app.include_router(order_router)
app.include_router(menu_router)
app.include_router(staff_router)
app.include_router(staff_request_router)
app.include_router(realtime_router)
app.include_router(admin_router)


@app.get("/health")
async def health_check():
    return {"status": "ok", "env": settings.APP_ENV}
