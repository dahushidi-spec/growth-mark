"""成长报告路由：生成、列表、详情。"""

from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.honor import Honor
from app.models.share import GrowthReport
from app.models.user import Child, User
from app.models.work import Work
from app.schemas.common import ApiResponse, PageResponse
from app.services.ai_service import AIService

router = APIRouter(prefix="/reports", tags=["成长报告"])


class ReportGenerateRequest(BaseModel):
    """生成报告请求。"""

    child_id: int
    period: str = Field(
        ...,
        description="报告周期：'yearly' 年度 / 'quarterly' 季度，"
        "或自定义格式如 '2025' / '2025-Q1'",
    )
    year: Optional[int] = Field(None, description="年度，如 2025")
    quarter: Optional[int] = Field(None, description="季度 1-4，仅 period=quarterly 时使用")


class ReportResponse(BaseModel):
    """报告响应。"""

    id: int
    child_id: int
    period: str
    content: str
    work_count: int = 0
    honor_count: int = 0
    generated_at: datetime

    model_config = {"from_attributes": True}


def _period_label(period: str, year: Optional[int], quarter: Optional[int]) -> str:
    """生成周期标签：'2025' 或 '2025-Q1'。"""
    if year is not None:
        if period == "quarterly" and quarter in (1, 2, 3, 4):
            return f"{year}-Q{quarter}"
        return str(year)
    # 未指定 year，使用当前年份
    now = datetime.now()
    if period == "quarterly" and quarter in (1, 2, 3, 4):
        return f"{now.year}-Q{quarter}"
    return str(now.year)


def _date_range(period: str, year: Optional[int], quarter: Optional[int]) -> tuple[date, date]:
    """根据周期计算起止日期。"""
    y = year or datetime.now().year
    if period == "quarterly" and quarter in (1, 2, 3, 4):
        start_month = (quarter - 1) * 3 + 1
        start = date(y, start_month, 1)
        if start_month + 2 == 12:
            end = date(y + 1, 1, 1)
        else:
            end = date(y, start_month + 3, 1)
    else:
        start = date(y, 1, 1)
        end = date(y + 1, 1, 1)
    return start, end


async def _validate_child_owned(db: AsyncSession, child_id: int, user_id: int) -> Child:
    """校验孩子档案归属。"""
    result = await db.execute(select(Child).where(Child.id == child_id))
    child = result.scalar_one_or_none()
    if child is None or child.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="孩子档案不存在"
        )
    return child


@router.post("/generate", response_model=ApiResponse[ReportResponse])
async def generate_report(
    req: ReportGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """生成成长报告（按季度/年度汇总作品与荣誉，调用 LLM 生成文本并存储）。"""
    await _validate_child_owned(db, req.child_id, current_user.id)

    period_label = _period_label(req.period, req.year, req.quarter)
    start_date, end_date = _date_range(req.period, req.year, req.quarter)

    # 汇总作品
    works = (
        await db.execute(
            select(Work).where(
                Work.user_id == current_user.id,
                Work.child_id == req.child_id,
                Work.is_deleted == False,  # noqa: E712
                Work.created_date >= start_date,
                Work.created_date < end_date,
            )
        )
    ).scalars().all()

    # 汇总荣誉
    honors = (
        await db.execute(
            select(Honor).where(
                Honor.user_id == current_user.id,
                Honor.child_id == req.child_id,
                Honor.award_date >= start_date,
                Honor.award_date < end_date,
            )
        )
    ).scalars().all()

    # 调用 AI 生成报告
    service = AIService()
    content = await service.generate_report(
        work_list=[{"title": w.title, "category": w.category.value} for w in works],
        honor_list=[{"title": h.title, "level": h.level.value} for h in honors],
    )

    # 存储报告
    report = GrowthReport(
        child_id=req.child_id,
        period=period_label,
        content=content,
    )
    db.add(report)
    await db.flush()
    await db.refresh(report)

    return ApiResponse(
        data=ReportResponse(
            id=report.id,
            child_id=report.child_id,
            period=report.period,
            content=report.content,
            work_count=len(works),
            honor_count=len(honors),
            generated_at=report.generated_at,
        )
    )


@router.get("", response_model=ApiResponse[PageResponse[ReportResponse]])
async def list_reports(
    child_id: Optional[int] = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """报告列表（按生成时间倒序）。"""
    # 通过孩子档案归属过滤
    child_subquery = select(Child.id).where(Child.user_id == current_user.id)
    conditions = [GrowthReport.child_id.in_(child_subquery)]
    if child_id is not None:
        conditions.append(GrowthReport.child_id == child_id)

    total = (
        await db.execute(
            select(func.count(GrowthReport.id)).where(and_(*conditions))
        )
    ).scalar_one()

    result = await db.execute(
        select(GrowthReport)
        .where(and_(*conditions))
        .order_by(GrowthReport.generated_at.desc(), GrowthReport.id.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    reports = result.scalars().all()
    items = [
        ReportResponse(
            id=r.id,
            child_id=r.child_id,
            period=r.period,
            content=r.content,
            work_count=0,  # 列表不统计，详情可单独查询
            honor_count=0,
            generated_at=r.generated_at,
        )
        for r in reports
    ]
    return ApiResponse(
        data=PageResponse(items=items, total=total, page=page, size=size)
    )


@router.get("/{report_id}", response_model=ApiResponse[ReportResponse])
async def get_report(
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """报告详情。"""
    result = await db.execute(
        select(GrowthReport).where(GrowthReport.id == report_id)
    )
    report = result.scalar_one_or_none()
    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="报告不存在"
        )

    # 校验孩子归属
    child_result = await db.execute(select(Child).where(Child.id == report.child_id))
    child = child_result.scalar_one_or_none()
    if child is None or child.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="无权查看该报告"
        )

    # 统计该周期内作品与荣誉数量（从 period 解析年份）
    try:
        year = int(report.period.split("-")[0])
        if "-Q" in report.period:
            quarter = int(report.period.split("-Q")[1])
            start, end = _date_range("quarterly", year, quarter)
        else:
            start, end = _date_range("yearly", year, None)
    except (ValueError, IndexError):
        start, end = _date_range("yearly", None, None)

    work_count = (
        await db.execute(
            select(func.count(Work.id)).where(
                Work.user_id == current_user.id,
                Work.child_id == report.child_id,
                Work.is_deleted == False,  # noqa: E712
                Work.created_date >= start,
                Work.created_date < end,
            )
        )
    ).scalar_one()

    honor_count = (
        await db.execute(
            select(func.count(Honor.id)).where(
                Honor.user_id == current_user.id,
                Honor.child_id == report.child_id,
                Honor.award_date >= start,
                Honor.award_date < end,
            )
        )
    ).scalar_one()

    return ApiResponse(
        data=ReportResponse(
            id=report.id,
            child_id=report.child_id,
            period=report.period,
            content=report.content,
            work_count=work_count,
            honor_count=honor_count,
            generated_at=report.generated_at,
        )
    )


@router.delete("/{report_id}", response_model=ApiResponse)
async def delete_report(
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除报告。"""
    result = await db.execute(
        select(GrowthReport).where(GrowthReport.id == report_id)
    )
    report = result.scalar_one_or_none()
    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="报告不存在"
        )

    # 校验孩子归属
    child_result = await db.execute(select(Child).where(Child.id == report.child_id))
    child = child_result.scalar_one_or_none()
    if child is None or child.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="无权删除该报告"
        )

    await db.delete(report)
    await db.flush()
    return ApiResponse(message="删除成功")
