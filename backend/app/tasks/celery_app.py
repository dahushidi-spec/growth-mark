"""Celery 应用配置。"""

from celery import Celery

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "growth_mark",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["app.tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Shanghai",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)

# 自动发现 app.tasks 包下的任务模块
celery_app.autodiscover_tasks(["app.tasks"])
