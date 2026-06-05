import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models.user import User
from app.models.venue import ResourceType
from app.repositories.venue_repository import VenueRepository
from app.schemas.chat import ChatRequest, ChatResponse
from app.services.chat_service import ChatService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["chat"])

_chat_service: ChatService | None = None

COURT_TYPE_LABELS = {
    "billiards": "bida",
    "pickleball": "pickleball",
    "badminton": "cầu lông",
}

RESOURCE_TYPE_TO_COURT_TYPE = {
    ResourceType.BILLIARDS_TABLE.value: "billiards",
    ResourceType.PICKLEBALL_COURT.value: "pickleball",
    ResourceType.BADMINTON_COURT.value: "badminton",
}


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
    _: None = Depends(rate_limit(limit=30, window_seconds=60, scope="chat")),
    user: User = Depends(get_current_user),
    chat_service: ChatService = Depends(_get_chat_service),
    session: AsyncSession = Depends(get_db),
) -> ChatResponse:
    """Process a chat message through the AI agent and return a response."""
    try:
        session_id = request.session_id or str(uuid.uuid4())

        # Build context with venue info
        context = dict(request.context) if request.context else {}
        context.setdefault("user_id", str(user.id))
        context.setdefault("user_name", user.name or "")
        context.setdefault("user_phone", user.phone or "")
        if request.context and "venue_id" in request.context:
            context["venue_id"] = request.context["venue_id"]
            context["venue_name"] = request.context.get("venue_name", "")
        context = await _hydrate_venue_context(context, user, session)

        result = await chat_service.process_message(
            message=request.message,
            session_id=session_id,
            user_id=str(user.id),
            context=context,
        )
        return result
    except Exception as exc:
        logger.exception("Error processing chat message")
        raise HTTPException(status_code=500, detail=f"Internal error: {exc}") from exc


async def _hydrate_venue_context(
    context: dict,
    user: User,
    session: AsyncSession,
) -> dict:
    """Add server-side venue facts so the agent does not ask for filtered types."""
    venue_id = context.get("venue_id")
    if not venue_id:
        return context

    repo = VenueRepository(session)
    try:
        resolved_venue_id = await repo.resolve_user_venue_id(
            user,
            explicit_venue_id=str(venue_id),
        )
    except ValueError:
        logger.warning("Ignoring invalid chat venue_id: %s", venue_id)
        return context
    if not resolved_venue_id:
        return context

    context["venue_id"] = str(resolved_venue_id)
    venue = await repo.get_venue_by_id(resolved_venue_id)
    if venue:
        if not context.get("venue_name"):
            context["venue_name"] = venue.name
        context["venue_timezone"] = venue.timezone

    rows = await repo.list_resources(
        venue_id=resolved_venue_id,
        status="active",
    )
    court_types: list[str] = []
    resource_labels: list[str] = []
    for row in rows:
        resource = row["resource"]
        court_type = _court_type_from_resource(resource)
        if court_type and court_type not in court_types:
            court_types.append(court_type)
        if court_type:
            label = getattr(resource, "name", None) or getattr(resource, "code", None)
            if label:
                resource_labels.append(str(label))

    if court_types:
        context["available_court_types"] = court_types
        context["available_court_type_names"] = [
            COURT_TYPE_LABELS.get(court_type, court_type)
            for court_type in court_types
        ]
        if len(court_types) == 1:
            context.setdefault("court_type", court_types[0])
            context.setdefault(
                "court_type_name",
                COURT_TYPE_LABELS.get(court_types[0], court_types[0]),
            )
    if resource_labels:
        context["available_resource_labels"] = resource_labels[:12]

    return context


def _court_type_from_resource(resource) -> str | None:
    sport_type = (getattr(resource, "sport_type", "") or "").lower()
    if sport_type in COURT_TYPE_LABELS:
        return sport_type

    resource_type = getattr(resource, "resource_type", "")
    resource_type_value = (
        resource_type.value if hasattr(resource_type, "value") else str(resource_type)
    )
    return RESOURCE_TYPE_TO_COURT_TYPE.get(resource_type_value)
