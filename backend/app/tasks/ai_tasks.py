"""AI 相关异步任务（Celery）。

在 Celery Worker 中执行 AI 识别与报告生成，避免阻塞 HTTP 请求。
任务可通过 `task_id` 查询状态与结果。
"""

import asyncio
import logging
from typing import Any

from app.services.ai_service import AIService
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    """在 Celery 同步任务中执行异步协程。"""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


@celery_app.task(name="ai.recognize", bind=True)
def recognize_image_task(self, image_url: str) -> dict[str, Any]:
    """异步识别作品图片。

    Args:
        image_url: 作品图片 URL

    Returns:
        dict: 包含 category/tags/description_suggestion/confidence 的识别结果
    """
    logger.info(f"[Celery] 开始 AI 识别任务 task_id={self.request.id}, image_url={image_url}")
    try:
        service = AIService()
        result = _run_async(service.recognize_image(image_url))
        logger.info(f"[Celery] AI 识别任务完成 task_id={self.request.id}")
        return result
    except Exception as e:  # noqa: BLE001
        logger.error(f"[Celery] AI 识别任务失败 task_id={self.request.id}: {e}")
        return {
            "category": "其他",
            "tags": [],
            "description_suggestion": "AI 识别任务执行失败",
            "confidence": 0.0,
        }


@celery_app.task(name="ai.generate_report", bind=True)
def generate_report_task(
    self, work_list: list[dict[str, Any]], honor_list: list[dict[str, Any]]
) -> str:
    """异步生成成长报告。

    Args:
        work_list: 作品列表 [{"title": ..., "category": ...}]
        honor_list: 荣誉列表 [{"title": ..., "level": ...}]

    Returns:
        str: 成长报告文本
    """
    logger.info(f"[Celery] 开始报告生成任务 task_id={self.request.id}")
    try:
        service = AIService()
        content = _run_async(service.generate_report(work_list, honor_list))
        logger.info(f"[Celery] 报告生成任务完成 task_id={self.request.id}")
        return content
    except Exception as e:  # noqa: BLE001
        logger.error(f"[Celery] 报告生成任务失败 task_id={self.request.id}: {e}")
        service = AIService()
        return service._fallback_report(work_list, honor_list)
