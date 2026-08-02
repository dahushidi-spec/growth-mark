"""分享路由：生成分享卡片、查看分享内容、分享记录管理。"""

import uuid
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.honor import Honor
from app.models.share import Share
from app.models.user import User
from app.models.work import Work
from app.schemas.common import ApiResponse, PageResponse

router = APIRouter(prefix="/shares", tags=["分享"])


class ShareCardRequest(BaseModel):
    """创建分享请求。"""

    work_id: Optional[int] = None
    honor_id: Optional[int] = None
    share_type: str = Field("work", description="分享类型：work/honor/report")
    expire_days: int = Field(7, ge=1, le=30)
    password: Optional[str] = Field(None, max_length=100, description="访问密码，留空则公开")


class ShareVerifyRequest(BaseModel):
    """访问密码校验请求。"""

    password: Optional[str] = None


class ShareResponse(BaseModel):
    """分享记录响应（含创建者视角）。"""

    id: int
    share_url: Optional[str] = None
    share_type: str
    has_password: bool = False
    expires_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_share(cls, share: Share) -> "ShareResponse":
        return cls(
            id=share.id,
            share_url=share.share_url,
            share_type=share.share_type,
            has_password=share.password is not None,
            expires_at=share.expires_at,
            created_at=share.created_at,
        )


class ShareContentResponse(BaseModel):
    """分享内容响应（公开访问视角，不含敏感字段）。"""

    id: int
    share_type: str
    title: str
    image_url: Optional[str] = None
    description: Optional[str] = None
    created_at: datetime
    expires_at: Optional[datetime] = None


@router.post("/card", response_model=ApiResponse[ShareResponse])
async def create_share_card(
    req: ShareCardRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """生成分享卡片（创建一条分享记录与随机访问 token）。"""
    if req.work_id is None and req.honor_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="必须指定 work_id 或 honor_id",
        )

    # 校验作品/荣誉归属
    if req.work_id is not None:
        work = (
            await db.execute(
                select(Work).where(
                    Work.id == req.work_id, Work.user_id == current_user.id
                )
            )
        ).scalar_one_or_none()
        if work is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="作品不存在"
            )
    if req.honor_id is not None:
        honor = (
            await db.execute(
                select(Honor).where(
                    Honor.id == req.honor_id, Honor.user_id == current_user.id
                )
            )
        ).scalar_one_or_none()
        if honor is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="荣誉不存在"
            )

    share_token = uuid.uuid4().hex
    share = Share(
        user_id=current_user.id,
        work_id=req.work_id,
        honor_id=req.honor_id,
        share_type=req.share_type,
        share_url=f"/s/{share_token}",
        password=req.password,
        expires_at=datetime.utcnow() + timedelta(days=req.expire_days),
    )
    db.add(share)
    await db.flush()
    await db.refresh(share)
    return ApiResponse(data=ShareResponse.from_share(share))


@router.get("", response_model=ApiResponse[PageResponse[ShareResponse]])
async def list_shares(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """我的分享记录列表。"""
    conditions = [Share.user_id == current_user.id]
    total = (
        await db.execute(
            select(func.count(Share.id)).where(and_(*conditions))
        )
    ).scalar_one()

    result = await db.execute(
        select(Share)
        .where(and_(*conditions))
        .order_by(Share.created_at.desc(), Share.id.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    shares = result.scalars().all()
    items = [ShareResponse.from_share(s) for s in shares]
    return ApiResponse(
        data=PageResponse(items=items, total=total, page=page, size=size)
    )


@router.get("/{share_id}", response_model=ApiResponse[ShareResponse])
async def get_share(
    share_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查看分享记录（仅创建者）。"""
    result = await db.execute(
        select(Share).where(Share.id == share_id, Share.user_id == current_user.id)
    )
    share = result.scalar_one_or_none()
    if share is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="分享不存在"
        )
    return ApiResponse(data=ShareResponse.from_share(share))


@router.post("/{share_id}/verify", response_model=ApiResponse[ShareContentResponse])
async def view_share(
    share_id: int,
    req: ShareVerifyRequest,
    db: AsyncSession = Depends(get_db),
):
    """公开访问分享内容（校验密码与过期时间）。

    返回分享的作品/荣誉内容（不含敏感信息）。
    """
    result = await db.execute(select(Share).where(Share.id == share_id))
    share = result.scalar_one_or_none()
    if share is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="分享不存在"
        )
    if share.expires_at is not None and share.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_410_GONE, detail="分享已过期"
        )
    if share.password is not None and share.password != req.password:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="密码错误"
        )

    # 加载关联的作品或荣誉内容
    title = ""
    image_url: Optional[str] = None
    description: Optional[str] = None

    if share.work_id is not None:
        work = (
            await db.execute(select(Work).where(Work.id == share.work_id))
        ).scalar_one_or_none()
        if work is not None:
            title = work.title
            image_url = work.image_url
            description = work.description
    elif share.honor_id is not None:
        honor = (
            await db.execute(select(Honor).where(Honor.id == share.honor_id))
        ).scalar_one_or_none()
        if honor is not None:
            title = honor.title
            image_url = honor.image_url
            description = honor.description

    return ApiResponse(
        data=ShareContentResponse(
            id=share.id,
            share_type=share.share_type,
            title=title,
            image_url=image_url,
            description=description,
            created_at=share.created_at,
            expires_at=share.expires_at,
        )
    )


@router.delete("/{share_id}", response_model=ApiResponse)
async def delete_share(
    share_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除分享记录（仅创建者）。"""
    result = await db.execute(
        select(Share).where(Share.id == share_id, Share.user_id == current_user.id)
    )
    share = result.scalar_one_or_none()
    if share is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="分享不存在"
        )
    await db.delete(share)
    await db.flush()
    return ApiResponse(message="删除成功")
