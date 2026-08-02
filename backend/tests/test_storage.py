"""存储服务测试：LocalStorageBackend + 缩略图生成 + OSS 配置判断。"""

import io
from pathlib import Path
from unittest.mock import patch

import pytest
from PIL import Image

from app.services.storage_service import (
    ALLOWED_IMAGE_TYPES,
    LocalStorageBackend,
    _generate_key,
    _make_thumbnail,
    is_oss_configured,
)


def _make_test_image(color: str = "RGB", size: tuple[int, int] = (800, 600)) -> bytes:
    """生成测试图片字节流。"""
    img = Image.new(color, size, (255, 100, 50))
    buf = io.BytesIO()
    fmt = "PNG" if color in ("RGBA", "P") else "JPEG"
    img.save(buf, format=fmt)
    return buf.getvalue()


class TestGenerateKey:
    """_generate_key 测试。"""

    def test_generate_key_with_known_content_type(self):
        """已知 content_type 返回对应扩展名。"""
        key = _generate_key("test.jpg", "image/png")
        assert key.endswith(".png")
        assert "/" in key  # 包含日期目录

    def test_generate_key_with_unknown_content_type(self):
        """未知 content_type 退回 filename 后缀。"""
        key = _generate_key("photo.bin", "application/octet-stream")
        assert key.endswith(".bin")

    def test_generate_key_with_unknown_content_type_no_ext(self):
        """未知 content_type 且无后缀使用 .bin。"""
        key = _generate_key("noext", "application/octet-stream")
        assert key.endswith(".bin")

    def test_generate_key_uniqueness(self):
        """两次生成应产生不同键（UUID）。"""
        k1 = _generate_key("a.jpg", "image/jpeg")
        k2 = _generate_key("a.jpg", "image/jpeg")
        assert k1 != k2


class TestMakeThumbnail:
    """_make_thumbnail 测试。"""

    def test_thumbnail_max_size(self):
        """缩略图最大边不超过 300。"""
        data = _make_test_image(size=(800, 600))
        thumb = _make_thumbnail(data, "image/jpeg")
        img = Image.open(io.BytesIO(thumb))
        assert max(img.size) <= 300

    def test_thumbnail_rgba_to_jpeg(self):
        """RGBA 透明通道应合成白底 JPEG。"""
        data = _make_test_image(color="RGBA", size=(400, 400))
        thumb = _make_thumbnail(data, "image/png")
        img = Image.open(io.BytesIO(thumb))
        assert img.mode == "RGB"

    def test_thumbnail_palette_mode(self):
        """P 模式（调色板）应正确转换。"""
        data = _make_test_image(color="P", size=(400, 400))
        thumb = _make_thumbnail(data, "image/png")
        img = Image.open(io.BytesIO(thumb))
        assert img.mode == "RGB"


class TestLocalStorageBackend:
    """LocalStorageBackend 测试。"""

    @pytest.mark.asyncio
    async def test_save_returns_urls(self, tmp_path: Path):
        """保存文件应返回 url 和 thumbnail_url。"""
        backend = LocalStorageBackend(base_dir=tmp_path, base_url="http://test")
        data = _make_test_image()
        url, thumb_url = await backend.save(data, "test.jpg", "image/jpeg")

        assert url.startswith("http://test/uploads/")
        assert ".jpg" in url
        assert thumb_url.startswith("http://test/uploads/")
        assert "_thumb.jpg" in thumb_url

    @pytest.mark.asyncio
    async def test_save_creates_files(self, tmp_path: Path):
        """保存后应在磁盘生成原图和缩略图。"""
        backend = LocalStorageBackend(base_dir=tmp_path, base_url="")
        data = _make_test_image()
        url, thumb_url = await backend.save(data, "test.png", "image/png")

        # 提取相对路径并校验文件存在
        rel_path = url.replace("/uploads/", "")
        thumb_rel = thumb_url.replace("/uploads/", "")
        assert (tmp_path / rel_path).exists()
        assert (tmp_path / thumb_rel).exists()


class TestOSSConfig:
    """OSS 配置判断测试。"""

    def test_is_oss_configured_false_by_default(self):
        """默认配置应返回 False。"""
        # 测试环境通常未配置 OSS
        result = is_oss_configured()
        assert result is False

    @patch("app.services.storage_service.settings")
    def test_is_oss_configured_true(self, mock_settings):
        """三个字段都配置后返回 True。"""
        mock_settings.OSS_ACCESS_KEY_ID = "ak"
        mock_settings.OSS_ACCESS_KEY_SECRET = "sk"
        mock_settings.OSS_BUCKET_NAME = "bucket"
        assert is_oss_configured() is True

    @patch("app.services.storage_service.settings")
    def test_is_oss_configured_partial(self, mock_settings):
        """部分配置返回 False。"""
        mock_settings.OSS_ACCESS_KEY_ID = "ak"
        mock_settings.OSS_ACCESS_KEY_SECRET = ""
        mock_settings.OSS_BUCKET_NAME = "bucket"
        assert is_oss_configured() is False


def test_allowed_image_types():
    """ALLOWED_IMAGE_TYPES 应包含四种类型。"""
    assert "image/jpeg" in ALLOWED_IMAGE_TYPES
    assert "image/png" in ALLOWED_IMAGE_TYPES
    assert "image/webp" in ALLOWED_IMAGE_TYPES
    assert "image/gif" in ALLOWED_IMAGE_TYPES
