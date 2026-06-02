from contextvars import ContextVar

current_user_id: ContextVar[str] = ContextVar(
    "current_user_id",
    default="chatbot_user",
)

current_chat_context: ContextVar[dict | None] = ContextVar(
    "current_chat_context",
    default=None,
)
