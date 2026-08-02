"""认证相关模型。"""

from typing import Optional

from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    """注册请求。"""

    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")
    password: str = Field(..., min_length=6, max_length=20)
    nickname: str = Field(..., max_length=50)
    verification_code: str = Field(..., min_length=4, max_length=6)


class LoginRequest(BaseModel):
    """登录请求。"""

    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")
    password: str = Field(..., min_length=6)


class SendCodeRequest(BaseModel):
    """发送验证码请求。"""

    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")


class TokenResponse(BaseModel):
    """令牌响应。"""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: Optional["UserResponse"] = None


class RefreshTokenRequest(BaseModel):
    """刷新令牌请求。"""

    refresh_token: str


class UserResponse(BaseModel):
    """用户信息响应。"""

    id: int
    phone: str
    nickname: str
    avatar_url: Optional[str] = None

    model_config = {"from_attributes": True}


# 解析 TokenResponse 中 UserResponse 的前向引用
TokenResponse.model_rebuild()
