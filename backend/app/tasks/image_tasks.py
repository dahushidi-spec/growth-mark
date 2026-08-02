"""图片处理异步任务（Celery）。

用于后台生成缩略图、压缩图片，避免阻塞上传接口。
"""

import logging
from io import BytesIO
from pathlib import Path

from PIL import Image

from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="image.compress", bind=True)
def compress_image_task(
    self, source_path: str, target_path: str, max_size: tuple[int, int] = (1024, 1024)
) -> dict:
    """异步压缩图片并保存到目标路径。

    Args:
        source_path: 源图片路径
        target_path: 压缩后保存路径
        max_size: 最大尺寸（宽, 高）

    Returns:
        dict: 包含 success/path/width/height 字段
    """
    logger.info(f"[Celery] 开始图片压缩任务 task_id={self.request.id}, source={source_path}")
    try:
        src = Path(source_path)
        if not src.exists():
            return {"success": False, "error": "源文件不存在"}

        with Image.open(src) as img:
            img = img.convert("RGB")
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            target = Path(target_path)
            target.parent.mkdir(parents=True, exist_ok=True)
            img.save(target, format="JPEG", quality=85, optimize=True)
            logger.info(
                f"[Celery] 图片压缩完成 task_id={self.request.id}, "
                f"size={img.size}, saved={target_path}"
            )
            return {
                "success": True,
                "path": str(target),
                "width": img.width,
                "height": img.height,
            }
    except Exception as e:  # noqa: BLE001
        logger.error(f"[Celery] 图片压缩任务失败 task_id={self.request.id}: {e}")
        return {"success": False, "error": str(e)}


@celery_app.task(name="image.thumbnail", bind=True)
def generate_thumbnail_task(
    self, source_path: str, target_path: str, size: int = 300
) -> dict:
    """异步生成缩略图（等比缩放，最大边为 size）。

    Args:
        source_path: 源图片路径
        target_path: 缩略图保存路径
        size: 最大边长

    Returns:
        dict: 包含 success/path 字段
    """
    logger.info(f"[Celery] 开始缩略图任务 task_id={self.request.id}, source={source_path}")
    try:
        src = Path(source_path)
        if not src.exists():
            return {"success": False, "error": "源文件不存在"}

        with Image.open(src) as img:
            img = img.convert("RGB")
            img.thumbnail((size, size), Image.Resampling.LANCZOS)
            target = Path(target_path)
            target.parent.mkdir(parents=True, exist_ok=True)
            buf = BytesIO()
            img.save(buf, format="JPEG", quality=80, optimize=True)
            target.write_bytes(buf.getvalue())
            logger.info(
                f"[Celery] 缩略图生成完成 task_id={self.request.id}, size={img.size}"
            )
            return {"success": True, "path": str(target)}
    except Exception as e:  # noqa: BLE001
        logger.error(f"[Celery] 缩略图任务失败 task_id={self.request.id}: {e}")
        return {"success": False, "error": str(e)}
