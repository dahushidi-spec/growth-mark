"""荣誉服务接口测试：CRUD、级别筛选、统计。"""

from tests.test_auth import _register_user
from tests.test_children import _child_payload


async def _setup(client, phone="13800000070"):
    """注册用户 + 创建孩子档案，返回 (headers, child_id)。"""
    data = await _register_user(client, phone)
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post("/api/v1/children", headers=headers, json=_child_payload())
    return headers, resp.json()["data"]["id"]


def _honor_payload(child_id, title="绘画一等奖", level="市级", award_date="2026-05-01"):
    return {
        "title": title,
        "level": level,
        "category": "绘画",
        "image_url": "http://example.com/cert.jpg",
        "award_date": award_date,
        "organization": "市少年宫",
        "description": "获奖故事",
        "child_id": child_id,
    }


# ============ 统计 ============

async def test_honor_stats_empty(client):
    """无荣誉时统计应全为 0。"""
    headers, _ = await _setup(client, "13800000071")
    resp = await client.get("/api/v1/honors/stats", headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["total"] == 0
    assert data["this_year"] == 0
    assert data["high_level"] == 0


async def test_honor_stats_with_data(client):
    """统计应正确反映总数、本年、高级别。"""
    headers, child_id = await _setup(client, "13800000072")
    # 国家级 1 个（高级别）
    await client.post(
        "/api/v1/honors",
        headers=headers,
        json=_honor_payload(child_id, level="国家级", title="国家级奖"),
    )
    # 省级 1 个（高级别）
    await client.post(
        "/api/v1/honors",
        headers=headers,
        json=_honor_payload(child_id, level="省级", title="省级奖"),
    )
    # 市级 1 个（非高级别）
    await client.post(
        "/api/v1/honors",
        headers=headers,
        json=_honor_payload(child_id, level="市级", title="市级奖"),
    )

    resp = await client.get("/api/v1/honors/stats", headers=headers)
    data = resp.json()["data"]
    assert data["total"] == 3
    assert data["this_year"] == 3
    assert data["high_level"] == 2


# ============ 列表与筛选 ============

async def test_list_honors_by_level(client):
    """按级别筛选荣誉。"""
    headers, child_id = await _setup(client, "13800000073")
    await client.post(
        "/api/v1/honors",
        headers=headers,
        json=_honor_payload(child_id, level="国家级"),
    )
    await client.post(
        "/api/v1/honors",
        headers=headers,
        json=_honor_payload(child_id, level="校级"),
    )

    resp = await client.get(
        "/api/v1/honors", headers=headers, params={"level": "国家级"}
    )
    data = resp.json()["data"]
    assert data["total"] == 1
    assert data["items"][0]["level"] == "国家级"


async def test_list_honors_data_isolation(client):
    """用户只能看到自己的荣誉。"""
    headers_a, child_id_a = await _setup(client, "13800000074")
    await client.post(
        "/api/v1/honors",
        headers=headers_a,
        json=_honor_payload(child_id_a),
    )

    data_b = await _register_user(client, "13800000075")
    headers_b = {"Authorization": f"Bearer {data_b['access_token']}"}
    resp = await client.get("/api/v1/honors", headers=headers_b)
    assert resp.json()["data"]["total"] == 0


# ============ 详情 / 删除 ============

async def test_get_honor_success(client):
    """获取荣誉详情应成功。"""
    headers, child_id = await _setup(client, "13800000076")
    create_resp = await client.post(
        "/api/v1/honors", headers=headers, json=_honor_payload(child_id)
    )
    honor_id = create_resp.json()["data"]["id"]
    resp = await client.get(f"/api/v1/honors/{honor_id}", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["data"]["id"] == honor_id


async def test_delete_honor(client):
    """删除荣誉后列表不再包含。"""
    headers, child_id = await _setup(client, "13800000077")
    create_resp = await client.post(
        "/api/v1/honors", headers=headers, json=_honor_payload(child_id)
    )
    honor_id = create_resp.json()["data"]["id"]

    resp = await client.delete(f"/api/v1/honors/{honor_id}", headers=headers)
    assert resp.status_code == 200

    list_resp = await client.get("/api/v1/honors", headers=headers)
    assert list_resp.json()["data"]["total"] == 0


async def test_get_honor_other_user(client):
    """不能查看他人荣誉。"""
    headers_a, child_id_a = await _setup(client, "13800000078")
    create_resp = await client.post(
        "/api/v1/honors", headers=headers_a, json=_honor_payload(child_id_a)
    )
    honor_id = create_resp.json()["data"]["id"]

    data_b = await _register_user(client, "13800000079")
    headers_b = {"Authorization": f"Bearer {data_b['access_token']}"}
    resp = await client.get(f"/api/v1/honors/{honor_id}", headers=headers_b)
    assert resp.status_code == 404
