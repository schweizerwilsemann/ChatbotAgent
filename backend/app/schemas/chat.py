from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4096, description="User message")
    session_id: str | None = Field(
        None, description="Session ID for conversation continuity"
    )


class ChatResponse(BaseModel):
    response: str = Field(..., description="AI assistant reply")
    session_id: str = Field(..., description="Session ID for conversation continuity")
    tools_used: list[str] = Field(
        default_factory=list, description="List of tools invoked"
    )
