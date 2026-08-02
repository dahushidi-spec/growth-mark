"""分享服务接口测试：创建卡片、查看分享、密码校验、删除。

Share 模型包含 password 字段，支持公开/加密两种分享方式。
"""

from tests.test_auth import _register_user
from tests.test_children import _child_payload


async def _setup(client, phone="13800000110"):
    """注册用户 + 创建孩子档案 + 创建一件作品。

    返回 (headers, child_id, work_id)。
    """
    data = await _register_user(client, phone)
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post("/api/v1/children", headers=headers, json=_child_payload())
    child_id = resp.json()["data"]["id"]

    work_resp = await client.post(
        "/api/v1/works",
        headers=headers,
        json={
            "title": "我的画",
            "category": "绘画",
            "description": "孩子的作品",
            "image_url": "http://example.com/img.jpg",
            "thumbnail_url": "http://example.com/thumb.jpg",
            "created_date": "2026-06-01",
            "child_id": child_id,
            "tags": ["水彩"],
        },
    )
    work_id = work_resp.json()["data"]["id"]
    return headers, child_id, work_id


# ============ 创建分享 ============

async def test_create_share_card(client):
    """创建分享卡片应返回 id、share_url 与 has_password=False。"""
    headers, _, work_id = await _setup(client, "13800000111")
    resp = await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "share_type": "work"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "id" in data
    assert data["share_url"]
    assert data["has_password"] is False


async def test_create_share_with_password(client):
    """带密码创建分享应返回 has_password=True。"""
    headers, _, work_id = await _setup(client, "13800000112")
    resp = await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "password": "1234"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["has_password"] is True


async def test_create_share_no_target(client):
    """未指定 work_id 或 honor_id 应返回 400。"""
    data = await _register_user(client, "13800000113")
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post("/api/v1/shares/card", headers=headers, json={})
    assert resp.status_code == 400


# ============ 列表 / 详情 ============

async def test_list_shares(client):
    """创建分享后列表应非空。"""
    headers, _, work_id = await _setup(client, "13800000114")
    await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "share_type": "work"},
    )
    resp = await client.get("/api/v1/shares", headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["total"] >= 1
    assert len(data["items"]) >= 1


async def test_get_share(client):
    """获取分享记录详情应成功。"""
    headers, _, work_id = await _setup(client, "13800000115")
    create_resp = await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "share_type": "work"},
    )
    share_id = create_resp.json()["data"]["id"]
    resp = await client.get(f"/api/v1/shares/{share_id}", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["data"]["id"] == share_id


# ============ 公开访问 / 密码校验 ============

async def test_view_share_no_password(client):
    """无密码分享可直接访问，返回 title 与 image_url。"""
    headers, _, work_id = await _setup(client, "13800000116")
    create_resp = await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "share_type": "work"},
    )
    share_id = create_resp.json()["data"]["id"]

    resp = await client.post(
        f"/api/v1/shares/{share_id}/verify", json={"password": None}
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["title"] == "我的画"
    assert data["image_url"] == "http://example.com/img.jpg"


async def test_view_share_with_password_correct(client):
    """正确密码访问带密码分享应返回 200。"""
    headers, _, work_id = await _setup(client, "13800000117")
    create_resp = await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "password": "1234"},
    )
    share_id = create_resp.json()["data"]["id"]

    resp = await client.post(
        f"/api/v1/shares/{share_id}/verify", json={"password": "1234"}
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["title"] == "我的画"


async def test_view_share_with_password_wrong(client):
    """错误密码访问应返回 403。"""
    headers, _, work_id = await _setup(client, "13800000118")
    create_resp = await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "password": "1234"},
    )
    share_id = create_resp.json()["data"]["id"]

    resp = await client.post(
        f"/api/v1/shares/{share_id}/verify", json={"password": "wrong"}
    )
    assert resp.status_code == 403


async def test_view_share_not_found(client):
    """访问不存在的分享应返回 404。"""
    resp = await client.post(
        "/api/v1/shares/99999/verify", json={"password": None}
    )
    assert resp.status_code == 404


# ============ 删除 ============

async def test_delete_share(client):
    """删除分享后再次获取应返回 404。"""
    headers, _, work_id = await _setup(client, "13800000119")
    create_resp = await client.post(
        "/api/v1/shares/card",
        headers=headers,
        json={"work_id": work_id, "share_type": "work"},
    )
    share_id = create_resp.json()["data"]["id"]

    del_resp = await client.delete(f"/api/v1/shares/{share_id}", headers=headers)
    assert del_resp.status_code == 200

    get_resp = await client.get(f"/api/v1/shares/{share_id}", headers=headers)
    assert get_resp.status_code == 404
