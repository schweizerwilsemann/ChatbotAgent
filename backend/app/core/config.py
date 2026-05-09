from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "Sports Venue AI Chatbot"
    APP_VERSION: str = "1.0.0"
    APP_ENV: str = "development"
    DEBUG: bool = False

    # PostgreSQL
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/sports_venue"

    # Neo4j
    NEO4J_URI: str = "bolt://localhost:7687"
    NEO4J_USERNAME: str = "neo4j"
    NEO4J_PASSWORD: str = "password"
    NEO4J_DATABASE: str = "neo4j"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    SESSION_TTL: int = 3600  # 1 hour
    MENU_CACHE_TTL_SECONDS: int = 300
    MENU_CACHE_VERSION: str = "v1"
    KG_CACHE_TTL_SECONDS: int = 21600
    KG_CACHE_VERSION: str = "v1"

    # LLM
    GEMINI_API_KEY: str = ""
    GOOGLE_API_KEY: str = ""
    LLM_PROVIDER: str = "google"  # "google", "mimo", or "ollama"
    LLM_MODEL: str = "gemini-2.0-flash"
    OLLAMA_FALLBACK_MODEL: str = "qwen2.5-coder:7b"
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    LLM_TEMPERATURE: float = 0.3
    LLM_MAX_TOKENS: int = 2048

    # MiMo (Xiaomi) - OpenAI-compatible API
    MIMO_API_KEY: str = ""
    MIMO_API_BASE_URL: str = "https://token-plan-sgp.xiaomimimo.com/v1"
    MIMO_MODEL: str = "mimo-v2.5"

    # Embedding
    EMBEDDING_MODEL: str = "models/text-embedding-004"
    EMBEDDING_DIMENSION: int = 768

    # Secret
    SECRET_KEY: str = "change-me-in-production"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
