from pydantic import BaseModel, Field, field_validator


class CameraResponse(BaseModel):
    id: str
    venue_id: str
    resource_id: str | None = None
    resource_label: str | None = None
    name: str
    ip_address: str
    port: int
    username: str
    camera_brand: str
    rtsp_url: str
    is_active: bool


class CameraCreate(BaseModel):
    venue_id: str | None = None
    resource_id: str | None = None
    name: str = Field(..., min_length=1, max_length=255)
    ip_address: str = Field(..., min_length=1, max_length=45)
    port: int = Field(554, ge=1, le=65535)
    username: str = Field("admin", min_length=1, max_length=128)
    password: str = Field("", max_length=255)
    camera_brand: str = "custom"
    rtsp_url_override: str | None = Field(None, max_length=1024)

    @field_validator("camera_brand")
    @classmethod
    def validate_brand(cls, value: str) -> str:
        allowed = {"hik", "dahua", "seetong", "fpt", "custom"}
        normalized = value.lower()
        if normalized not in allowed:
            raise ValueError(f"camera_brand must be one of {allowed}")
        return normalized


class CameraUpdate(BaseModel):
    resource_id: str | None = None
    name: str | None = Field(None, min_length=1, max_length=255)
    ip_address: str | None = Field(None, min_length=1, max_length=45)
    port: int | None = Field(None, ge=1, le=65535)
    username: str | None = Field(None, min_length=1, max_length=128)
    password: str | None = Field(None, max_length=255)
    camera_brand: str | None = None
    rtsp_url_override: str | None = Field(None, max_length=1024)
    is_active: bool | None = None

    @field_validator("camera_brand")
    @classmethod
    def validate_brand(cls, value: str | None) -> str | None:
        if value is None:
            return value
        allowed = {"hik", "dahua", "seetong", "fpt", "custom"}
        normalized = value.lower()
        if normalized not in allowed:
            raise ValueError(f"camera_brand must be one of {allowed}")
        return normalized
