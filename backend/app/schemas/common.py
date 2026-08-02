"""通用响应与分页模型。"""

from typing import Generic, Optional, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class ResponseBase(BaseModel):
    """响应基础结构。"""

    code: int = 200
    message: str = "success"


class ApiResponse(ResponseBase, Generic[T]):
    """统一泛型响应：{"code": 200, "message": "success", "data": {...}}"""

    data: Optional[T] = None


class PageRequest(BaseModel):
    """分页请求参数。"""

    page: int = Field(1, ge=1)
    size: int = Field(20, ge=1, le=100)


class PageResponse(BaseModel, Generic[T]):
    """分页响应。"""

    items: list[T]
    total: int
    page: int
    size: int
