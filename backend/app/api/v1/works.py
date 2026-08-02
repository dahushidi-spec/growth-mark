"""作品路由：时间线、增删改查。"""

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import Child, User
from app.models.work import Work, WorkCategory, WorkTag
from app.schemas.child import calc_age
from app.schemas.common import ApiResponse, PageResponse
from app.schemas.work import WorkCreate, WorkResponse, WorkUpdate

router = APIRouter(prefix="/works", tags=["作品"])


def _own_work_or_404(work: Work | None, user_id: int) -> Work:
    if work is None or work.is_deleted or work.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="作品不存在")
    return work


async def _validate_child_owned(db: AsyncSession, child_id: int, user_id: int) -> Child:
    """校验孩子档案存在且属于当前用户，返回 Child 实例。"""
    result = await db.execute(select(Child).where(Child.id == child_id))
    child = result.scalar_one_or_none()
    if child is None or child.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="孩子档案不存在"
        )
    return child


@router.get("/timeline", response_model=ApiResponse[PageResponse[WorkResponse]])
async def get_timeline(
    child_id: int | None = None,
    category: WorkCategory | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取作品时间线（分页 + 筛选）。"""
    conditions = [Work.is_deleted == False, Work.user_id == current_user.id]  # noqa: E712
    if child_id is not None:
        conditions.append(Work.child_id == child_id)
    if category is not None:
        conditions.append(Work.category == category)
    if start_date is not None:
        conditions.append(Work.created_date >= start_date)
    if end_date is not None:
        conditions.append(Work.created_date <= end_date)

    total = (
        await db.execute(select(func.count(Work.id)).where(and_(*conditions)))
    ).scalar_one()

    result = await db.execute(
        select(Work)
        .options(selectinload(Work.tags))
        .where(and_(*conditions))
        .order_by(Work.created_date.desc(), Work.id.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    works = result.scalars().all()
    items = [WorkResponse.model_validate(w) for w in works]
    return ApiResponse(
        data=PageResponse(items=items, total=total, page=page, size=size)
    )


@router.post("", response_model=ApiResponse[WorkResponse])
async def create_work(
    req: WorkCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """创建作品。"""
    child = await _validate_child_owned(db, req.child_id, current_user.id)

    work = Work(
        child_id=req.child_id,
        user_id=current_user.id,
        title=req.title,
        category=req.category,
        description=req.description,
        image_url=req.image_url,
        thumbnail_url=req.thumbnail_url,
        created_date=req.created_date,
        child_age=calc_age(child.birth_date, req.created_date),
    )
    for tag_name in req.tags:
        work.tags.append(WorkTag(tag_name=tag_name, is_ai_generated=False))
    db.add(work)
    await db.flush()

    # 重新查询以加载关联与服务端默认值
    result = await db.execute(
        select(Work).options(selectinload(Work.tags)).where(Work.id == work.id)
    )
    work = result.scalar_one()
    return ApiResponse(data=WorkResponse.model_validate(work))


@router.get("/{work_id}", response_model=ApiResponse[WorkResponse])
async def get_work(
    work_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取作品详情。"""
    result = await db.execute(
        select(Work)
        .options(selectinload(Work.tags))
        .where(Work.id == work_id, Work.is_deleted == False)  # noqa: E712
    )
    work = _own_work_or_404(result.scalar_one_or_none(), current_user.id)
    return ApiResponse(data=WorkResponse.model_validate(work))


@router.put("/{work_id}", response_model=ApiResponse[WorkResponse])
async def update_work(
    work_id: int,
    req: WorkUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新作品。"""
    result = await db.execute(
        select(Work)
        .options(selectinload(Work.tags))
        .where(Work.id == work_id, Work.is_deleted == False)  # noqa: E712
    )
    work = _own_work_or_404(result.scalar_one_or_none(), current_user.id)

    data = req.model_dump(exclude_unset=True)
    # tags 单独处理：整体替换
    tags_value = data.pop("tags", None)
    for field, value in data.items():
        setattr(work, field, value)

    if tags_value is not None:
        # 清空旧标签
        work.tags.clear()
        for tag_name in tags_value:
            work.tags.append(WorkTag(tag_name=tag_name, is_ai_generated=False))

    await db.flush()

    result = await db.execute(
        select(Work).options(selectinload(Work.tags)).where(Work.id == work.id)
    )
    work = result.scalar_one()
    return ApiResponse(data=WorkResponse.model_validate(work))


@router.delete("/{work_id}", response_model=ApiResponse)
async def delete_work(
    work_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """软删除作品（is_deleted=True）。"""
    result = await db.execute(
        select(Work).where(Work.id == work_id, Work.is_deleted == False)  # noqa: E712
    )
    work = _own_work_or_404(result.scalar_one_or_none(), current_user.id)
    work.is_deleted = True
    await db.flush()
    return ApiResponse(message="删除成功")
