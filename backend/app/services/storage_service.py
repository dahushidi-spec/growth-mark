"""对象存储服务。

提供统一的文件存储接口，支持两种后端：
- LocalStorageBackend：本地文件系统（开发环境兜底，OSS 未配置时使用）
- OSSStorageBackend：阿里云 OSS（生产环境，配置 OSS_ACCESS_KEY_ID 后启用）

所有后端均返回可直接访问的 URL，并自动生成缩略图。
"""

import io
import uuid
from abc import ABC, abstractmethod
from datetime import datetime
from pathlib import Path

from loguru import logger
from PIL import Image

from app.core.config import get_settings

settings = get_settings()

# 缩略图最大边长（保持宽高比）
THUMBNAIL_MAX_SIZE = 300
# 允许的图片类型
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
# 图片扩展名映射
_EXT_MAP = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}


class StorageBackend(ABC):
    """存储后端抽象接口。"""

    @abstractmethod
    async def save(
        self, data: bytes, filename: str, content_type: str
    ) -> tuple[str, str]:
        """保存文件并返回 (url, thumbnail_url)。"""
        ...


def _generate_key(filename: str, content_type: str) -> str:
    """生成带日期目录的唯一存储键。"""
    ext = _EXT_MAP.get(content_type, Path(filename).suffix or ".bin")
    now = datetime.now()
    return f"{now.strftime('%Y/%m')}/{uuid.uuid4().hex}{ext}"


def _make_thumbnail(data: bytes, content_type: str) -> bytes:
    """生成缩略图（等比缩放，最大边长 THUMBNAIL_MAX_SIZE）。"""
    img = Image.open(io.BytesIO(data))
    img.thumbnail((THUMBNAIL_MAX_SIZE, THUMBNAIL_MAX_SIZE))

    buf = io.BytesIO()
    # 统一输出为 JPEG 格式（体积更小），若原图有透明通道则合成白底
    if img.mode in ("RGBA", "LA", "P"):
        background = Image.new("RGB", img.size, (255, 255, 255))
        if img.mode == "P":
            img = img.convert("RGBA")
        background.paste(img, mask=img.split()[-1] if img.mode == "RGBA" else None)
        img = background
    img.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


class LocalStorageBackend(StorageBackend):
    """本地文件系统存储后端。"""

    def __init__(self, base_dir: Path = Path("uploads"), base_url: str = ""):
        self._base_dir = base_dir
        self._base_url = base_url.rstrip("/")

    async def save(
        self, data: bytes, filename: str, content_type: str
    ) -> tuple[str, str]:
        key = _generate_key(filename, content_type)
        file_path = self._base_dir / key
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_bytes(data)

        # 生成并保存缩略图
        thumb_data = _make_thumbnail(data, content_type)
        thumb_key = key.rsplit(".", 1)[0] + "_thumb.jpg"
        thumb_path = self._base_dir / thumb_key
        thumb_path.write_bytes(thumb_data)

        url = f"{self._base_url}/uploads/{key}"
        thumb_url = f"{self._base_url}/uploads/{thumb_key}"
        logger.debug(f"[Local] 文件已保存: {file_path}")
        return url, thumb_url


class OSSStorageBackend(StorageBackend):
    """阿里云 OSS 存储后端。"""

    def __init__(self):
        import oss2

        auth = oss2.Auth(
            settings.OSS_ACCESS_KEY_ID, settings.OSS_ACCESS_KEY_SECRET
        )
        self._bucket = oss2.Bucket(
            auth, settings.OSS_ENDPOINT, settings.OSS_BUCKET_NAME
        )
        self._cdn_domain = settings.OSS_CDN_DOMAIN.rstrip("/")
        self._prefix = "growth-mark"

    async def save(
        self, data: bytes, filename: str, content_type: str
    ) -> tuple[str, str]:
        import asyncio

        key = f"{self._prefix}/{_generate_key(filename, content_type)}"
        thumb_key = key.rsplit(".", 1)[0] + "_thumb.jpg"
        thumb_data = _make_thumbnail(data, content_type)

        # oss2 是同步 SDK，用线程池执行避免阻塞事件循环
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            lambda: self._bucket.put_object(key, data),
        )
        await loop.run_in_executor(
            None,
            lambda: self._bucket.put_object(thumb_key, thumb_data),
        )

        base = self._cdn_domain or f"https://{settings.OSS_BUCKET_NAME}.{settings.OSS_ENDPOINT}"
        url = f"{base}/{key}"
        thumb_url = f"{base}/{thumb_key}"
        logger.debug(f"[OSS] 文件已上传: {key}")
        return url, thumb_url


def is_oss_configured() -> bool:
    """判断 OSS 是否已配置。"""
    return bool(
        settings.OSS_ACCESS_KEY_ID
        and settings.OSS_ACCESS_KEY_SECRET
        and settings.OSS_BUCKET_NAME
    )


_storage_instance: StorageBackend | None = None


def get_storage() -> StorageBackend:
    """获取存储后端单例（OSS 优先，本地兜底）。"""
    global _storage_instance
    if _storage_instance is None:
        if is_oss_configured():
            logger.info("使用阿里云 OSS 存储后端")
            _storage_instance = OSSStorageBackend()
        else:
            logger.info("使用本地文件存储后端（OSS 未配置）")
            # 返回相对 URL，由前端同源访问（nginx 反向代理 /uploads/ 到后端）
            _storage_instance = LocalStorageBackend(base_url="")
    return _storage_instance
