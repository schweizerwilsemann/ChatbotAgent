import json
import logging
import uuid

from app.agent.agent import AgentResponse, VenueAgent
from app.core.config import settings
from app.core.redis_client import redis_client
from app.schemas.chat import ChatResponse

logger = logging.getLogger(__name__)


class ChatService:
    def __init__(self, agent: VenueAgent) -> None:
        self._agent = agent
        self._session_ttl = settings.SESSION_TTL

    async def process_message(self, message: str, session_id: str) -> ChatResponse:
        """Process a chat message, maintaining conversation history in Redis."""
        history = await self._load_history(session_id)

        history.append({"role": "user", "content": message})

        try:
            agent_response: AgentResponse = await self._agent.process(
                message=message,
                session_history=history,
            )
        except Exception as exc:
            logger.exception("Agent processing failed for session %s", session_id)
            agent_response = AgentResponse(
                output="Xin lỗi, tôi đang gặp sự cố. Vui lòng thử lại sau.",
                tools_used=[],
            )

        history.append({"role": "assistant", "content": agent_response.output})
        await self._save_history(session_id, history)

        return ChatResponse(
            response=agent_response.output,
            session_id=session_id,
            tools_used=agent_response.tools_used,
        )

    async def _load_history(self, session_id: str) -> list[dict]:
        """Load conversation history from Redis."""
        try:
            raw = await redis_client.get(f"session:{session_id}")
            if raw:
                return json.loads(raw)
        except Exception:
            logger.warning("Failed to load session %s, starting fresh", session_id)
        return []

    async def _save_history(self, session_id: str, history: list[dict]) -> None:
        """Save conversation history to Redis with TTL."""
        try:
            await redis_client.set(
                f"session:{session_id}",
                json.dumps(history, ensure_ascii=False),
                ex=self._session_ttl,
            )
        except Exception:
            logger.warning("Failed to save session %s", session_id)
