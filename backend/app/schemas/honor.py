"""荣誉相关模型。"""

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.models.honor import HonorLevel


class HonorCreate(BaseModel):
    """创建荣誉请求。"""

    title: str = Field(..., max_length=100)
    level: HonorLevel
    category: str = Field(..., max_length=50)
    image_url: Optional[str] = None
    award_date: date
    organization: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    child_id: int


class HonorResponse(BaseModel):
    """荣誉详情响应。"""

    id: int
    child_id: int
    user_id: int
    title: str
    level: HonorLevel
    category: str
    image_url: Optional[str] = None
    award_date: date
    organization: Optional[str] = None
    description: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class HonorStats(BaseModel):
    """荣誉统计响应。"""

    total: int
    this_year: int
    high_level: int
