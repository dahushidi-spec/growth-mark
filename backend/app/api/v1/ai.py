"""AI 路由：图像识别、成长报告生成、异步任务管理。"""

from datetime import date
from typing import Any, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.honor import Honor
from app.models.user import User
from app.models.work import Work
from app.schemas.common import ApiResponse
from app.services.ai_service import AIService
from app.tasks.ai_tasks import recognize_image_task

router = APIRouter(prefix="/ai", tags=["AI 服务"])


class RecognizeRequest(BaseModel):
    image_url: str = Field(..., description="待识别的作品图片 URL")


class AsyncRecognizeResponse(BaseModel):
    task_id: str
    status: str = "PENDING"


class TaskStatusResponse(BaseModel):
    task_id: str
    status: str
    result: Optional[Any] = None
    error: Optional[str] = None


class ReportRequest(BaseModel):
    child_id: int
    start_date: Optional[date] = None
    end_date: Optional[date] = None


class ReportResponse(BaseModel):
    content: str


@router.post("/recognize", response_model=ApiResponse)
async def recognize_image(
    req: RecognizeRequest,
    current_user: User = Depends(get_current_user),
):
    """同步识别作品图片，返回分类建议与标签。"""
    service = AIService()
    result = await service.recognize_image(req.image_url)
    return ApiResponse(data=result)


@router.post("/recognize/async", response_model=ApiResponse[AsyncRecognizeResponse])
async def recognize_image_async(
    req: RecognizeRequest,
    current_user: User = Depends(get_current_user),
):
    """提交异步 AI 识别任务，返回 task_id 供轮询查询。"""
    task = recognize_image_task.delay(req.image_url)
    return ApiResponse(
        data=AsyncRecognizeResponse(task_id=task.id, status="PENDING")
    )


@router.get("/tasks/{task_id}", response_model=ApiResponse[TaskStatusResponse])
async def get_task_status(
    task_id: str,
    current_user: User = Depends(get_current_user),
):
    """查询异步任务状态。

    status 取值：PENDING / STARTED / SUCCESS / FAILURE / RETRY
    """
    from celery.result import AsyncResult

    result = AsyncResult(task_id)
    status = result.status

    response = TaskStatusResponse(task_id=task_id, status=status)
    if status == "SUCCESS":
        response.result = result.result
    elif status == "FAILURE":
        response.error = str(result.result)
    return ApiResponse(data=response)


@router.post("/report", response_model=ApiResponse[ReportResponse])
async def generate_report(
    req: ReportRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """根据孩子的作品与荣誉生成成长报告（同步）。"""
    work_conditions = [
        Work.user_id == current_user.id,
        Work.child_id == req.child_id,
        Work.is_deleted == False,  # noqa: E712
    ]
    if req.start_date is not None:
        work_conditions.append(Work.created_date >= req.start_date)
    if req.end_date is not None:
        work_conditions.append(Work.created_date <= req.end_date)

    works = (
        await db.execute(select(Work).where(*work_conditions))
    ).scalars().all()

    honor_conditions = [
        Honor.user_id == current_user.id,
        Honor.child_id == req.child_id,
    ]
    honors = (
        await db.execute(select(Honor).where(*honor_conditions))
    ).scalars().all()

    service = AIService()
    content = await service.generate_report(
        work_list=[{"title": w.title, "category": w.category.value} for w in works],
        honor_list=[{"title": h.title, "level": h.level.value} for h in honors],
    )
    return ApiResponse(data=ReportResponse(content=content))
