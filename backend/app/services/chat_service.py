import json
import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.agent.context import current_chat_context, current_user_id
from app.agent.agent import AgentResponse, VenueAgent
from app.core.config import settings
from app.core.redis_client import redis_client
from app.schemas.chat import ChatResponse

logger = logging.getLogger(__name__)


class ChatService:
    def __init__(self, agent: VenueAgent) -> None:
        self._agent = agent
        self._session_ttl = settings.SESSION_TTL

    async def process_message(
        self,
        message: str,
        session_id: str,
        user_id: str = "chatbot_user",
        context: dict | None = None,
    ) -> ChatResponse:
        """Process a chat message, maintaining conversation history in Redis."""
        history = await self._load_history(session_id)

        # Keep the selected venue context in the current turn, not only history.
        chat_context = dict(context or {})
        self._add_time_context(chat_context)
        enriched_message = self._enrich_message_with_context(message, chat_context)

        history.append({"role": "user", "content": message})

        try:
            user_token = current_user_id.set(user_id)
            context_token = current_chat_context.set(chat_context)
            try:
                agent_response: AgentResponse = await self._agent.process(
                    message=enriched_message,
                    session_history=history,
                )
            finally:
                current_chat_context.reset(context_token)
                current_user_id.reset(user_token)
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
            metadata=agent_response.metadata,
        )

    @classmethod
    def _enrich_message_with_context(cls, message: str, context: dict) -> str:
        context = dict(context or {})
        cls._add_time_context(context)
        parts = []
        current_datetime = context.get("current_datetime")
        current_date = context.get("current_date")
        current_time = context.get("current_time")
        current_timezone = context.get("current_timezone")
        tomorrow_date = context.get("tomorrow_date")
        if current_datetime and current_date and current_time:
            parts.append(f"current_datetime={current_datetime}")
            parts.append(f"current_date={current_date}")
            parts.append(f"current_time={current_time}")
            parts.append(f"timezone={current_timezone}")
            parts.append(f"hôm nay={current_date}")
            if tomorrow_date:
                parts.append(f"ngày mai={tomorrow_date}")

        venue_name = context.get("venue_name")
        if venue_name:
            parts.append(f"venue_name={venue_name}")
        elif context.get("venue_id"):
            parts.append("venue đã chọn")

        available_names = context.get("available_court_type_names") or []
        available_types = context.get("available_court_types") or []
        if available_names:
            parts.append(f"loại sân tại venue={', '.join(map(str, available_names))}")
        elif available_types:
            parts.append(f"court_types={', '.join(map(str, available_types))}")

        court_type = context.get("court_type")
        court_type_name = context.get("court_type_name") or court_type
        if court_type:
            parts.append(f"court_type mặc định={court_type} ({court_type_name})")
            parts.append("không hỏi lại môn/loại sân trong booking")

        resource_labels = context.get("available_resource_labels") or []
        if resource_labels:
            parts.append(
                "bàn/sân hiện có="
                + ", ".join(str(label) for label in resource_labels[:8])
            )

        prefix = "[Ngữ cảnh hiện tại: " + "; ".join(parts) + "]"
        return f"{prefix}\n{message}"

    @staticmethod
    def _add_time_context(context: dict) -> None:
        timezone_name = (
            context.get("venue_timezone")
            or context.get("current_timezone")
            or settings.DEFAULT_TIMEZONE
        )
        try:
            tz = ZoneInfo(str(timezone_name))
        except (ZoneInfoNotFoundError, ValueError):
            timezone_name = settings.DEFAULT_TIMEZONE
            tz = ZoneInfo(timezone_name)

        now = datetime.now(tz)
        context["current_timezone"] = str(timezone_name)
        context["current_datetime"] = now.isoformat(timespec="seconds")
        context["current_date"] = now.date().isoformat()
        context["current_time"] = now.strftime("%H:%M:%S")
        context["tomorrow_date"] = (now + timedelta(days=1)).date().isoformat()

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
