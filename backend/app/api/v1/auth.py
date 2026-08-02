"""认证路由：发送验证码、注册、登录、刷新令牌、获取当前用户。"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
    verify_token,
)
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    SendCodeRequest,
    TokenResponse,
    UserResponse,
)
from app.schemas.common import ApiResponse
from app.services.sms_service import send_code, verify_code

router = APIRouter(prefix="/auth", tags=["认证"])


def _build_token_response(user: User) -> TokenResponse:
    """为用户签发访问/刷新令牌并组装响应。"""
    token_data = {"sub": str(user.id), "phone": user.phone}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/sms/send",
    response_model=ApiResponse[dict],
    summary="发送手机验证码",
    description="向指定手机号发送 6 位验证码（开发环境固定为 123456）。60 秒内不可重复发送，验证码 5 分钟有效。",
    responses={
        200: {
            "description": "发送成功",
            "content": {
                "application/json": {
                    "example": {"code": 200, "message": "success", "data": {"sent": True}}
                }
            },
        },
        429: {"description": "发送频率过高（60 秒内重复发送）"},
    },
)
async def send_sms_code(req: SendCodeRequest):
    """发送手机验证码。

    开发环境固定返回 123456（详见日志），生产环境接入短信通道。
    """
    try:
        await send_code(req.phone)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(e)
        )

    return ApiResponse(data={"sent": True})


@router.post(
    "/register",
    response_model=ApiResponse[TokenResponse],
    summary="用户注册",
    description="校验验证码 -> 查重手机号 -> 哈希密码 -> 创建用户 -> 签发访问/刷新令牌。",
    responses={
        400: {"description": "验证码错误或已过期 / 该手机号已注册"},
    },
)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """用户注册：校验验证码 -> 查重手机号 -> 哈希密码 -> 创建用户 -> 签发令牌。"""
    # 校验验证码
    if not await verify_code(req.phone, req.verification_code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="验证码错误或已过期"
        )

    existed = await db.execute(select(User).where(User.phone == req.phone))
    if existed.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="该手机号已注册"
        )

    user = User(
        phone=req.phone,
        password_hash=hash_password(req.password),
        nickname=req.nickname,
    )
    db.add(user)
    await db.flush()

    return ApiResponse(data=_build_token_response(user))


@router.post(
    "/login",
    response_model=ApiResponse[TokenResponse],
    summary="用户登录",
    description="校验手机号与密码 -> 签发访问/刷新令牌。",
    responses={401: {"description": "手机号或密码错误"}},
)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """用户登录：校验手机号与密码 -> 签发令牌。"""
    result = await db.execute(select(User).where(User.phone == req.phone))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(req.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="手机号或密码错误"
        )

    return ApiResponse(data=_build_token_response(user))


@router.post(
    "/refresh",
    response_model=ApiResponse[TokenResponse],
    summary="刷新访问令牌",
    description="使用刷新令牌换取新的访问/刷新令牌对。",
    responses={401: {"description": "无效的刷新令牌 / 用户不存在"}},
)
async def refresh(req: RefreshTokenRequest, db: AsyncSession = Depends(get_db)):
    """使用刷新令牌换取新的访问令牌。"""
    payload = verify_token(req.refresh_token)
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的刷新令牌"
        )

    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在"
        )

    return ApiResponse(data=_build_token_response(user))


@router.get(
    "/me",
    response_model=ApiResponse[UserResponse],
    summary="获取当前用户信息",
    description="返回当前登录用户的基本信息（需携带访问令牌）。",
    responses={401: {"description": "未授权"}},
)
async def me(current_user: User = Depends(get_current_user)):
    """获取当前登录用户信息。"""
    return ApiResponse(data=UserResponse.model_validate(current_user))
