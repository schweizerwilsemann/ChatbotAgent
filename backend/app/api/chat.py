import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException

from app.schemas.chat import ChatRequest, ChatResponse
from app.services.chat_service import ChatService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["chat"])

_chat_service: ChatService | None = None


def set_chat_service(service: ChatService) -> None:
    global _chat_service
    _chat_service = service


def _get_chat_service() -> ChatService:
    if _chat_service is None:
        raise HTTPException(status_code=503, detail="Chat service is not ready")
    return _chat_service


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    chat_service: ChatService = Depends(_get_chat_service),
) -> ChatResponse:
    """Process a chat message through the AI agent and return a response."""
    try:
        session_id = request.session_id or str(uuid.uuid4())
        result = await chat_service.process_message(
            message=request.message,
            session_id=session_id,
        )
        return result
    except Exception as exc:
        logger.exception("Error processing chat message")
        raise HTTPException(status_code=500, detail=f"Internal error: {exc}") from exc
