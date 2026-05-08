import json
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.redis_client import redis_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/staff", tags=["staff"])


class StaffNotifyRequest(BaseModel):
    message: str = Field(
        ..., min_length=1, max_length=1000, description="Notification message"
    )
    table_number: int = Field(0, ge=0, description="Table number (0 if not applicable)")


class StaffNotifyResponse(BaseModel):
    notification_id: str
    message: str
    table_number: int
    status: str
    timestamp: str


@router.post("/notify", response_model=StaffNotifyResponse, status_code=201)
async def notify_staff(request: StaffNotifyRequest) -> StaffNotifyResponse:
    """Send a notification to staff. Stores in Redis for pub/sub consumption."""
    notification_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()

    notification = {
        "id": notification_id,
        "message": request.message,
        "table_number": request.table_number,
        "status": "pending",
        "timestamp": timestamp,
    }

    try:
        await redis_client.set(
            f"staff_notification:{notification_id}",
            json.dumps(notification),
            ex=3600,
        )
        await redis_client.client.publish(
            "staff_notifications",
            json.dumps(notification),
        )
        logger.info(
            "Staff notification created: id=%s table=%d msg=%s",
            notification_id,
            request.table_number,
            request.message,
        )
    except Exception as exc:
        logger.exception("Failed to store staff notification in Redis")
        raise HTTPException(
            status_code=500, detail="Failed to send notification"
        ) from exc

    return StaffNotifyResponse(
        notification_id=notification_id,
        message=request.message,
        table_number=request.table_number,
        status="sent",
        timestamp=timestamp,
    )
