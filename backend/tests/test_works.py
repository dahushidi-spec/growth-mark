"""作品服务接口测试：CRUD、时间线筛选、软删除、标签。"""

from tests.test_auth import _register_user
from tests.test_children import _child_payload


async def _setup(client, phone="13800000050"):
    """注册用户 + 创建孩子档案，返回 (headers, child_id)。"""
    data = await _register_user(client, phone)
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post("/api/v1/children", headers=headers, json=_child_payload())
    return headers, resp.json()["data"]["id"]


def _work_payload(child_id, title="我的画", category="绘画", created_date="2026-06-01"):
    return {
        "title": title,
        "category": category,
        "description": "孩子的作品",
        "image_url": "http://example.com/img.jpg",
        "thumbnail_url": "http://example.com/img_thumb.jpg",
        "created_date": created_date,
        "child_id": child_id,
        "tags": ["水彩", "风景"],
    }


# ============ 创建 ============

async def test_create_work_success(client):
    """创建作品应返回完整信息，含 child_age 与 tags。"""
    headers, child_id = await _setup(client, "13800000051")
    resp = await client.post("/api/v1/works", headers=headers, json=_work_payload(child_id))
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["title"] == "我的画"
    assert data["thumbnail_url"] == "http://example.com/img_thumb.jpg"
    assert data["child_age"] is not None
    assert len(data["tags"]) == 2


async def test_create_work_invalid_child(client):
    """孩子档案不属于当前用户应返回 400。"""
    headers, _ = await _setup(client, "13800000052")
    resp = await client.post(
        "/api/v1/works", headers=headers, json=_work_payload(9999)
    )
    assert resp.status_code == 400


async def test_create_work_without_token(client):
    """未登录创建作品应返回 401。"""
    resp = await client.post("/api/v1/works", json=_work_payload(1))
    assert resp.status_code == 401


# ============ 时间线 ============

async def test_timeline_pagination_and_filter(client):
    """时间线支持分页与按分类筛选。"""
    headers, child_id = await _setup(client, "13800000053")
    # 创建 3 个绘画 + 1 个手工
    for i in range(3):
        await client.post(
            "/api/v1/works",
            headers=headers,
            json=_work_payload(child_id, title=f"绘画{i}", category="绘画"),
        )
    await client.post(
        "/api/v1/works",
        headers=headers,
        json=_work_payload(child_id, title="手工", category="手工"),
    )

    # 按分类筛选
    resp = await client.get(
        "/api/v1/works/timeline", headers=headers, params={"category": "绘画"}
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["total"] == 3
    assert all(item["category"] == "绘画" for item in data["items"])

    # 分页
    resp = await client.get(
        "/api/v1/works/timeline", headers=headers, params={"page": 1, "size": 2}
    )
    data = resp.json()["data"]
    assert len(data["items"]) == 2
    assert data["total"] == 4


async def test_timeline_date_filter(client):
    """时间线支持按日期范围筛选。"""
    headers, child_id = await _setup(client, "13800000054")
    await client.post(
        "/api/v1/works",
        headers=headers,
        json=_work_payload(child_id, created_date="2026-01-15"),
    )
    await client.post(
        "/api/v1/works",
        headers=headers,
        json=_work_payload(child_id, created_date="2026-05-15"),
    )

    resp = await client.get(
        "/api/v1/works/timeline",
        headers=headers,
        params={"start_date": "2026-03-01", "end_date": "2026-06-30"},
    )
    data = resp.json()["data"]
    assert data["total"] == 1
    assert data["items"][0]["created_date"] == "2026-05-15"


# ============ 详情 / 更新 / 删除 ============

async def test_get_work_success(client):
    """获取作品详情应成功。"""
    headers, child_id = await _setup(client, "13800000055")
    create_resp = await client.post(
        "/api/v1/works", headers=headers, json=_work_payload(child_id)
    )
    work_id = create_resp.json()["data"]["id"]
    resp = await client.get(f"/api/v1/works/{work_id}", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["data"]["id"] == work_id


async def test_get_work_other_user(client):
    """不能查看他人作品。"""
    headers_a, child_id_a = await _setup(client, "13800000056")
    create_resp = await client.post(
        "/api/v1/works", headers=headers_a, json=_work_payload(child_id_a)
    )
    work_id = create_resp.json()["data"]["id"]

    data_b = await _register_user(client, "13800000057")
    headers_b = {"Authorization": f"Bearer {data_b['access_token']}"}
    resp = await client.get(f"/api/v1/works/{work_id}", headers=headers_b)
    assert resp.status_code == 404


async def test_update_work_with_tags(client):
    """更新作品含 tags 应整体替换。"""
    headers, child_id = await _setup(client, "13800000058")
    create_resp = await client.post(
        "/api/v1/works", headers=headers, json=_work_payload(child_id)
    )
    work_id = create_resp.json()["data"]["id"]

    resp = await client.put(
        f"/api/v1/works/{work_id}",
        headers=headers,
        json={"title": "新标题", "tags": ["新标签"]},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["title"] == "新标题"
    assert len(data["tags"]) == 1
    assert data["tags"][0]["tag_name"] == "新标签"


async def test_soft_delete_work(client):
    """软删除后列表不再可见，但直接访问返回 404。"""
    headers, child_id = await _setup(client, "13800000059")
    create_resp = await client.post(
        "/api/v1/works", headers=headers, json=_work_payload(child_id)
    )
    work_id = create_resp.json()["data"]["id"]

    resp = await client.delete(f"/api/v1/works/{work_id}", headers=headers)
    assert resp.status_code == 200

    # 列表中不再可见
    list_resp = await client.get("/api/v1/works/timeline", headers=headers)
    assert list_resp.json()["data"]["total"] == 0

    # 直接访问返回 404
    get_resp = await client.get(f"/api/v1/works/{work_id}", headers=headers)
    assert get_resp.status_code == 404
