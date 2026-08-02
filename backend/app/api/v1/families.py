"""家庭路由：创建、加入、成员管理。"""

import secrets
import string

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.family import Family, FamilyMember, FamilyRole
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.family import (
    FamilyCreate,
    FamilyMemberResponse,
    FamilyResponse,
    JoinFamilyRequest,
)

router = APIRouter(prefix="/families", tags=["家庭"])


async def _generate_invite_code(db: AsyncSession) -> str:
    """生成 6 位唯一邀请码（使用 secrets 保证随机性）。"""
    chars = string.ascii_uppercase + string.digits
    for _ in range(10):
        code = "".join(secrets.choice(chars) for _ in range(6))
        existed = await db.execute(select(Family).where(Family.invite_code == code))
        if existed.scalar_one_or_none() is None:
            return code
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="邀请码生成失败"
    )


async def _build_family_response(db: AsyncSession, family: Family) -> FamilyResponse:
    """构建家庭响应，从数据库重新加载成员并关联用户信息（避免缓存陈旧）。"""
    # 直接查询成员表，避免 ORM 关系缓存导致新加入成员不可见
    members_result = await db.execute(
        select(FamilyMember).where(FamilyMember.family_id == family.id)
    )
    members = members_result.scalars().all()

    user_ids = [m.user_id for m in members]
    user_map: dict[int, User] = {}
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        user_map = {u.id: u for u in users_result.scalars().all()}

    member_items = []
    for m in members:
        u = user_map.get(m.user_id)
        member_items.append(
            FamilyMemberResponse(
                id=m.id,
                user_id=m.user_id,
                nickname=u.nickname if u else "",
                avatar_url=u.avatar_url if u else None,
                role=m.role,
                joined_at=m.joined_at,
            )
        )
    return FamilyResponse(
        id=family.id,
        name=family.name,
        invite_code=family.invite_code,
        creator_id=family.creator_id,
        created_at=family.created_at,
        members=member_items,
    )


@router.post("", response_model=ApiResponse[FamilyResponse])
async def create_family(
    req: FamilyCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """创建家庭，自动生成 6 位邀请码，创建者成为 creator。"""
    invite_code = await _generate_invite_code(db)
    family = Family(
        name=req.name,
        invite_code=invite_code,
        creator_id=current_user.id,
    )
    family.members.append(
        FamilyMember(user_id=current_user.id, role=FamilyRole.creator)
    )
    db.add(family)
    await db.flush()

    result = await db.execute(
        select(Family).options(selectinload(Family.members)).where(Family.id == family.id)
    )
    family = result.scalar_one()
    return ApiResponse(data=await _build_family_response(db, family))


@router.post("/join", response_model=ApiResponse[FamilyResponse])
async def join_family(
    req: JoinFamilyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """通过邀请码加入家庭。"""
    result = await db.execute(
        select(Family).options(selectinload(Family.members)).where(
            Family.invite_code == req.invite_code
        )
    )
    family = result.scalar_one_or_none()
    if family is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="邀请码无效"
        )

    # 已是成员则直接返回
    if any(m.user_id == current_user.id for m in family.members):
        return ApiResponse(data=await _build_family_response(db, family))

    member = FamilyMember(
        family_id=family.id, user_id=current_user.id, role=FamilyRole.member
    )
    db.add(member)
    await db.flush()

    result = await db.execute(
        select(Family).options(selectinload(Family.members)).where(Family.id == family.id)
    )
    family = result.scalar_one()
    return ApiResponse(data=await _build_family_response(db, family))


@router.get("/{family_id}/members", response_model=ApiResponse[list[FamilyMemberResponse]])
async def list_members(
    family_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取家庭成员列表（需为该家庭成员）。"""
    result = await db.execute(
        select(FamilyMember).where(FamilyMember.family_id == family_id)
    )
    members = result.scalars().all()
    if not any(m.user_id == current_user.id for m in members):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="无权查看该家庭成员"
        )

    # 关联用户信息
    user_ids = [m.user_id for m in members]
    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    user_map = {u.id: u for u in users_result.scalars().all()}

    items = []
    for m in members:
        u = user_map.get(m.user_id)
        items.append(
            FamilyMemberResponse(
                id=m.id,
                user_id=m.user_id,
                nickname=u.nickname if u else "",
                avatar_url=u.avatar_url if u else None,
                role=m.role,
                joined_at=m.joined_at,
            )
        )
    return ApiResponse(data=items)


@router.delete("/{family_id}/members/{user_id}", response_model=ApiResponse)
async def remove_member(
    family_id: int,
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """移除家庭成员（仅 creator/admin 可操作）。"""
    operator_result = await db.execute(
        select(FamilyMember).where(
            FamilyMember.family_id == family_id,
            FamilyMember.user_id == current_user.id,
        )
    )
    operator = operator_result.scalar_one_or_none()
    if operator is None or operator.role == FamilyRole.member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="无权移除家庭成员"
        )

    target_result = await db.execute(
        select(FamilyMember).where(
            FamilyMember.family_id == family_id,
            FamilyMember.user_id == user_id,
        )
    )
    target = target_result.scalar_one_or_none()
    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="成员不存在"
        )
    if target.role == FamilyRole.creator:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="不能移除家庭创建者"
        )

    await db.delete(target)
    await db.flush()
    return ApiResponse(message="移除成功")
