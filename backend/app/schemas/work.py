"""作品相关模型。"""

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.models.work import WorkCategory


class WorkTagSchema(BaseModel):
    """作品标签。"""

    id: int
    tag_name: str
    is_ai_generated: bool

    model_config = {"from_attributes": True}


class WorkCreate(BaseModel):
    """创建作品请求。"""

    title: str = Field(..., max_length=100)
    category: WorkCategory
    description: Optional[str] = None
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    created_date: date
    child_id: int
    tags: list[str] = Field(default_factory=list)


class WorkUpdate(BaseModel):
    """更新作品请求。"""

    title: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    category: Optional[WorkCategory] = None
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    tags: Optional[list[str]] = None


class WorkResponse(BaseModel):
    """作品详情响应。"""

    id: int
    child_id: int
    user_id: int
    family_id: Optional[int] = None
    title: str
    category: WorkCategory
    description: Optional[str] = None
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    created_date: date
    child_age: Optional[str] = None
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    tags: list[WorkTagSchema] = []

    model_config = {"from_attributes": True}


class TimelineItem(BaseModel):
    """时间线条目（用于作品/荣誉混合时间线）。"""

    id: int
    child_id: int
    title: str
    category: WorkCategory
    description: Optional[str] = None
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    created_date: date
    item_type: str = "work"
    tags: list[WorkTagSchema] = []

    model_config = {"from_attributes": True}
