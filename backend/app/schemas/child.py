"""孩子档案相关模型。"""

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


def calc_age(birth_date: date, today: Optional[date] = None) -> str:
    """根据出生日期计算年龄，返回 'X岁X月' 格式。

    不足 1 月时返回 'X天'，不足 1 岁时返回 'X月'。
    """
    today = today or date.today()
    years = today.year - birth_date.year
    months = today.month - birth_date.month

    if today.day < birth_date.day:
        months -= 1

    if months < 0:
        years -= 1
        months += 12

    if years <= 0 and months <= 0:
        days = (today - birth_date).days
        return f"{days}天"

    if years <= 0:
        return f"{months}个月"

    if months <= 0:
        return f"{years}岁"
    return f"{years}岁{months}个月"


class ChildCreate(BaseModel):
    """创建孩子档案请求。"""

    name: str = Field(..., min_length=1, max_length=50)
    gender: int = Field(0, ge=0, le=1, description="0女 1男")
    birth_date: date
    avatar_url: Optional[str] = Field(None, max_length=500)

    @field_validator("birth_date")
    @classmethod
    def validate_birth_date(cls, v: date) -> date:
        if v > date.today():
            raise ValueError("出生日期不能晚于今天")
        return v


class ChildUpdate(BaseModel):
    """更新孩子档案请求。"""

    name: Optional[str] = Field(None, min_length=1, max_length=50)
    gender: Optional[int] = Field(None, ge=0, le=1)
    birth_date: Optional[date] = None
    avatar_url: Optional[str] = Field(None, max_length=500)

    @field_validator("birth_date")
    @classmethod
    def validate_birth_date(cls, v: Optional[date]) -> Optional[date]:
        if v is not None and v > date.today():
            raise ValueError("出生日期不能晚于今天")
        return v


class ChildResponse(BaseModel):
    """孩子档案响应。"""

    id: int
    user_id: int
    name: str
    gender: int
    birth_date: date
    avatar_url: Optional[str] = None
    age: str
    created_at: datetime

    model_config = {"from_attributes": True}
