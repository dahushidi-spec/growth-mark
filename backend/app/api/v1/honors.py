"""荣誉路由：列表、增删查、统计。"""

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.honor import Honor, HonorLevel
from app.models.user import Child, User
from app.schemas.common import ApiResponse, PageResponse
from app.schemas.honor import HonorCreate, HonorResponse, HonorStats

router = APIRouter(prefix="/honors", tags=["荣誉"])


def _own_honor_or_404(honor: Honor | None, user_id: int) -> Honor:
    if honor is None or honor.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="荣誉不存在")
    return honor


async def _validate_child_owned(db: AsyncSession, child_id: int, user_id: int) -> Child:
    """校验孩子档案存在且属于当前用户，返回 Child 实例。"""
    result = await db.execute(select(Child).where(Child.id == child_id))
    child = result.scalar_one_or_none()
    if child is None or child.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="孩子档案不存在"
        )
    return child


@router.get("/stats", response_model=ApiResponse[HonorStats])
async def get_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """荣誉统计：总数、本年数量、高等级（国家级+省级）数量。"""
    owner = Honor.user_id == current_user.id
    total = (
        await db.execute(select(func.count(Honor.id)).where(owner))
    ).scalar_one()

    this_year = (
        await db.execute(
            select(func.count(Honor.id)).where(
                owner, Honor.award_date >= date(date.today().year, 1, 1)
            )
        )
    ).scalar_one()

    high_level = (
        await db.execute(
            select(func.count(Honor.id)).where(
                owner,
                Honor.level.in_([HonorLevel.national, HonorLevel.provincial]),
            )
        )
    ).scalar_one()

    return ApiResponse(
        data=HonorStats(total=total, this_year=this_year, high_level=high_level)
    )


@router.get("", response_model=ApiResponse[PageResponse[HonorResponse]])
async def list_honors(
    child_id: int | None = None,
    level: HonorLevel | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """荣誉列表（分页 + 筛选）。"""
    conditions = [Honor.user_id == current_user.id]
    if child_id is not None:
        conditions.append(Honor.child_id == child_id)
    if level is not None:
        conditions.append(Honor.level == level)
    if start_date is not None:
        conditions.append(Honor.award_date >= start_date)
    if end_date is not None:
        conditions.append(Honor.award_date <= end_date)

    total = (
        await db.execute(select(func.count(Honor.id)).where(and_(*conditions)))
    ).scalar_one()

    result = await db.execute(
        select(Honor)
        .where(and_(*conditions))
        .order_by(Honor.award_date.desc(), Honor.id.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    honors = result.scalars().all()
    items = [HonorResponse.model_validate(h) for h in honors]
    return ApiResponse(
        data=PageResponse(items=items, total=total, page=page, size=size)
    )


@router.post("", response_model=ApiResponse[HonorResponse])
async def create_honor(
    req: HonorCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """创建荣誉。"""
    # 校验孩子档案归属，防止引用他人 child_id
    await _validate_child_owned(db, req.child_id, current_user.id)

    honor = Honor(
        child_id=req.child_id,
        user_id=current_user.id,
        title=req.title,
        level=req.level,
        category=req.category,
        image_url=req.image_url,
        award_date=req.award_date,
        organization=req.organization,
        description=req.description,
    )
    db.add(honor)
    await db.flush()
    await db.refresh(honor)
    return ApiResponse(data=HonorResponse.model_validate(honor))


@router.get("/{honor_id}", response_model=ApiResponse[HonorResponse])
async def get_honor(
    honor_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """荣誉详情。"""
    result = await db.execute(select(Honor).where(Honor.id == honor_id))
    honor = _own_honor_or_404(result.scalar_one_or_none(), current_user.id)
    return ApiResponse(data=HonorResponse.model_validate(honor))


@router.delete("/{honor_id}", response_model=ApiResponse)
async def delete_honor(
    honor_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除荣誉。"""
    result = await db.execute(select(Honor).where(Honor.id == honor_id))
    honor = _own_honor_or_404(result.scalar_one_or_none(), current_user.id)
    await db.delete(honor)
    await db.flush()
    return ApiResponse(message="删除成功")
