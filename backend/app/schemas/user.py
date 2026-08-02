"""用户档案相关模型。"""

from typing import Optional

from pydantic import BaseModel, Field


class UserUpdate(BaseModel):
    """更新用户信息请求。"""

    nickname: Optional[str] = Field(None, min_length=1, max_length=50)
    avatar_url: Optional[str] = Field(None, max_length=500)
