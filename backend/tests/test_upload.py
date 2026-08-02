"""文件上传接口测试。"""

import io
from unittest.mock import AsyncMock, patch

from PIL import Image

from tests.test_auth import _register_user


def _make_test_image_bytes(size=(100, 100), fmt="JPEG") -> bytes:
    """生成测试图片二进制数据。"""
    img = Image.new("RGB", size, color=(255, 100, 50))
    buf = io.BytesIO()
    img.save(buf, format=fmt)
    return buf.getvalue()


async def _get_auth_token(client, phone="13800000020") -> str:
    """注册用户并返回 access_token。"""
    data = await _register_user(client, phone)
    return data["access_token"]


# ============ 上传成功 ============

async def test_upload_image_success(client):
    """上传合法图片应返回 url 与 thumbnail_url。"""
    token = await _get_auth_token(client)
    img_bytes = _make_test_image_bytes()

    mock_storage = AsyncMock()
    mock_storage.save = AsyncMock(
        return_value=(
            "http://localhost:8000/uploads/2026/06/test.jpg",
            "http://localhost:8000/uploads/2026/06/test_thumb.jpg",
        )
    )
    with patch("app.api.v1.upload.get_storage", return_value=mock_storage):
        resp = await client.post(
            "/api/v1/upload/image",
            headers={"Authorization": f"Bearer {token}"},
            files={"file": ("test.jpg", img_bytes, "image/jpeg")},
        )

    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "url" in data
    assert "thumbnail_url" in data
    assert data["file_size"] == len(img_bytes)
    assert data["content_type"] == "image/jpeg"


async def test_upload_png_image(client):
    """上传 PNG 图片应成功。"""
    token = await _get_auth_token(client, "13800000021")
    img_bytes = _make_test_image_bytes(fmt="PNG")

    mock_storage = AsyncMock()
    mock_storage.save = AsyncMock(
        return_value=("http://localhost:8000/uploads/test.png", "http://localhost:8000/uploads/test_thumb.jpg")
    )
    with patch("app.api.v1.upload.get_storage", return_value=mock_storage):
        resp = await client.post(
            "/api/v1/upload/image",
            headers={"Authorization": f"Bearer {token}"},
            files={"file": ("test.png", img_bytes, "image/png")},
        )

    assert resp.status_code == 200


# ============ 权限校验 ============

async def test_upload_without_token(client):
    """未登录上传应返回 401。"""
    img_bytes = _make_test_image_bytes()
    resp = await client.post(
        "/api/v1/upload/image",
        files={"file": ("test.jpg", img_bytes, "image/jpeg")},
    )
    assert resp.status_code == 401


# ============ 类型校验 ============

async def test_upload_invalid_type(client):
    """非图片类型应返回 400。"""
    token = await _get_auth_token(client, "13800000022")
    resp = await client.post(
        "/api/v1/upload/image",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("test.txt", b"hello world", "text/plain")},
    )
    assert resp.status_code == 400
    assert "不支持" in resp.json()["detail"]


# ============ 大小校验 ============

async def test_upload_too_large(client):
    """超过 10MB 应返回 400。"""
    token = await _get_auth_token(client, "13800000023")
    # 构造超过 10MB 的数据
    big_data = b"\x00" * (10 * 1024 * 1024 + 1)
    resp = await client.post(
        "/api/v1/upload/image",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("big.jpg", big_data, "image/jpeg")},
    )
    assert resp.status_code == 400
    assert "10MB" in resp.json()["detail"]


async def test_upload_empty_file(client):
    """空文件应返回 400。"""
    token = await _get_auth_token(client, "13800000024")
    resp = await client.post(
        "/api/v1/upload/image",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("empty.jpg", b"", "image/jpeg")},
    )
    assert resp.status_code == 400
    assert "空" in resp.json()["detail"]
