"""家庭相关模型。"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.models.family import FamilyRole


class FamilyCreate(BaseModel):
    """创建家庭请求。"""

    name: str = Field(..., max_length=100)


class FamilyMemberResponse(BaseModel):
    """家庭成员响应。"""

    id: int
    user_id: int
    nickname: str
    avatar_url: Optional[str] = None
    role: FamilyRole
    joined_at: datetime

    model_config = {"from_attributes": True}


class FamilyResponse(BaseModel):
    """家庭详情响应。"""

    id: int
    name: str
    invite_code: str
    creator_id: int
    created_at: datetime
    members: list[FamilyMemberResponse] = []

    model_config = {"from_attributes": True}


class JoinFamilyRequest(BaseModel):
    """加入家庭请求。"""

    invite_code: str = Field(..., min_length=6, max_length=6)
