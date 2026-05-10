from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class MenuItemResponse(BaseModel):
    id: str | None = None
    name: str
    description: str
    price: Decimal
    image_url: str | None = None
    category: str
    category_key: str | None = None
    unit: str | None = None
    tags: str | None = None
    sales_count: int = 0
    is_available: bool = True
    created_at: datetime | None = None
    updated_at: datetime | None = None


class MenuCategoryResponse(BaseModel):
    name: str
    items: list[MenuItemResponse] = Field(default_factory=list)


class MenuSuggestionResponse(BaseModel):
    query: str
    items: list[MenuItemResponse]
    prompt: str
