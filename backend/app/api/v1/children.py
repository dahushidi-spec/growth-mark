"""孩子档案路由：CRUD；以及用户档案更新接口。"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import Child, User
from app.schemas.auth import UserResponse
from app.schemas.child import ChildCreate, ChildResponse, ChildUpdate, calc_age
from app.schemas.common import ApiResponse
from app.schemas.user import UserUpdate

router = APIRouter(tags=["档案"])


def _to_response(child: Child) -> ChildResponse:
    """将 Child 模型转为响应，自动计算年龄。"""
    return ChildResponse(
        id=child.id,
        user_id=child.user_id,
        name=child.name,
        gender=child.gender,
        birth_date=child.birth_date,
        avatar_url=child.avatar_url,
        age=calc_age(child.birth_date),
        created_at=child.created_at,
    )


# ============ 用户档案 ============

@router.put("/users/me", response_model=ApiResponse[UserResponse])
async def update_me(
    req: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新当前用户信息（昵称、头像）。"""
    for field, value in req.model_dump(exclude_unset=True).items():
        setattr(current_user, field, value)
    await db.flush()
    return ApiResponse(data=UserResponse.model_validate(current_user))


# ============ 孩子档案 ============

@router.get("/children", response_model=ApiResponse[list[ChildResponse]])
async def list_children(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取当前用户的所有孩子档案（支持多子女）。"""
    result = await db.execute(
        select(Child).where(Child.user_id == current_user.id).order_by(Child.birth_date)
    )
    children = result.scalars().all()
    return ApiResponse(data=[_to_response(c) for c in children])


@router.post("/children", response_model=ApiResponse[ChildResponse])
async def create_child(
    req: ChildCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """创建孩子档案。"""
    child = Child(
        user_id=current_user.id,
        name=req.name,
        gender=req.gender,
        birth_date=req.birth_date,
        avatar_url=req.avatar_url,
    )
    db.add(child)
    await db.flush()
    await db.refresh(child)
    return ApiResponse(data=_to_response(child))


@router.get("/children/{child_id}", response_model=ApiResponse[ChildResponse])
async def get_child(
    child_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取孩子档案详情。"""
    result = await db.execute(select(Child).where(Child.id == child_id))
    child = result.scalar_one_or_none()
    if child is None or child.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="孩子档案不存在"
        )
    return ApiResponse(data=_to_response(child))


@router.put("/children/{child_id}", response_model=ApiResponse[ChildResponse])
async def update_child(
    child_id: int,
    req: ChildUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新孩子档案。"""
    result = await db.execute(select(Child).where(Child.id == child_id))
    child = result.scalar_one_or_none()
    if child is None or child.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="孩子档案不存在"
        )

    for field, value in req.model_dump(exclude_unset=True).items():
        setattr(child, field, value)
    await db.flush()
    await db.refresh(child)
    return ApiResponse(data=_to_response(child))


@router.delete("/children/{child_id}", response_model=ApiResponse)
async def delete_child(
    child_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除孩子档案（级联删除关联作品/荣誉）。"""
    result = await db.execute(select(Child).where(Child.id == child_id))
    child = result.scalar_one_or_none()
    if child is None or child.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="孩子档案不存在"
        )

    await db.delete(child)
    await db.flush()
    return ApiResponse(message="删除成功")
