"""图片处理 Celery 任务测试。

直接调用任务函数（不经过 broker），覆盖压缩/缩略图/错误分支。
"""

from pathlib import Path

import pytest
from PIL import Image

from app.tasks.image_tasks import compress_image_task, generate_thumbnail_task


def _make_test_image(path: Path, size: tuple[int, int] = (1200, 900)):
    """生成测试图片到指定路径。"""
    img = Image.new("RGB", size, (100, 150, 200))
    img.save(path, format="JPEG", quality=95)


@pytest.fixture(autouse=True)
def celery_request_context():
    """为 bind=True 的 Celery 任务注入 request 上下文。"""
    for task in (compress_image_task, generate_thumbnail_task):
        task.push_request(task_id="test-task-id-1234")
    yield
    for task in (compress_image_task, generate_thumbnail_task):
        task.pop_request()


class TestCompressImageTask:
    """compress_image_task 测试。"""

    def test_compress_success(self, tmp_path: Path):
        """正常压缩应返回 success=True。"""
        src = tmp_path / "src.jpg"
        _make_test_image(src, size=(1200, 900))
        target = tmp_path / "out" / "compressed.jpg"

        result = compress_image_task.run(str(src), str(target))

        assert result["success"] is True
        assert result["path"] == str(target)
        assert target.exists()
        # 尺寸应不超过 1024
        img = Image.open(target)
        assert max(img.size) <= 1024

    def test_compress_source_not_exist(self, tmp_path: Path):
        """源文件不存在应返回 success=False。"""
        result = compress_image_task.run(
            str(tmp_path / "nope.jpg"), str(tmp_path / "out.jpg")
        )
        assert result["success"] is False
        assert "不存在" in result["error"]

    def test_compress_invalid_image(self, tmp_path: Path):
        """非图片文件应返回 success=False（异常分支）。"""
        src = tmp_path / "bad.jpg"
        src.write_bytes(b"not an image")
        result = compress_image_task.run(str(src), str(tmp_path / "out.jpg"))
        assert result["success"] is False


class TestGenerateThumbnailTask:
    """generate_thumbnail_task 测试。"""

    def test_thumbnail_success(self, tmp_path: Path):
        """正常生成缩略图应返回 success=True。"""
        src = tmp_path / "src.jpg"
        _make_test_image(src, size=(800, 600))
        target = tmp_path / "thumb" / "t.jpg"

        result = generate_thumbnail_task.run(str(src), str(target), size=200)

        assert result["success"] is True
        assert result["path"] == str(target)
        assert target.exists()
        img = Image.open(target)
        assert max(img.size) <= 200

    def test_thumbnail_source_not_exist(self, tmp_path: Path):
        """源文件不存在应返回 success=False。"""
        result = generate_thumbnail_task.run(
            str(tmp_path / "nope.jpg"), str(tmp_path / "t.jpg")
        )
        assert result["success"] is False
        assert "不存在" in result["error"]

    def test_thumbnail_default_size(self, tmp_path: Path):
        """默认 size=300 应正确生效。"""
        src = tmp_path / "src.jpg"
        _make_test_image(src, size=(1000, 800))
        target = tmp_path / "t.jpg"

        result = generate_thumbnail_task.run(str(src), str(target))

        assert result["success"] is True
        img = Image.open(target)
        assert max(img.size) <= 300
