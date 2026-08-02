"""成长报告接口测试：生成、列表、详情、删除、归属校验。"""

from tests.test_auth import _register_user
from tests.test_children import _child_payload


async def _setup(client, phone="13800000100"):
    """注册用户 + 创建孩子档案 + 创建 2 件作品与 1 项荣誉（2026 年）。

    返回 (headers, child_id)。
    """
    data = await _register_user(client, phone)
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post("/api/v1/children", headers=headers, json=_child_payload())
    child_id = resp.json()["data"]["id"]

    for i in range(2):
        await client.post(
            "/api/v1/works",
            headers=headers,
            json={
                "title": f"作品{i}",
                "category": "绘画",
                "description": "描述",
                "image_url": "http://example.com/img.jpg",
                "thumbnail_url": "http://example.com/thumb.jpg",
                "created_date": "2026-03-15",
                "child_id": child_id,
                "tags": ["水彩"],
            },
        )
    await client.post(
        "/api/v1/honors",
        headers=headers,
        json={
            "title": "绘画一等奖",
            "level": "市级",
            "category": "绘画",
            "image_url": "http://example.com/cert.jpg",
            "award_date": "2026-04-10",
            "organization": "少年宫",
            "description": "获奖",
            "child_id": child_id,
        },
    )
    return headers, child_id


# ============ 生成报告 ============

async def test_generate_yearly_report(client):
    """生成年度报告应返回完整字段并正确统计作品/荣誉数。"""
    headers, child_id = await _setup(client, "13800000101")
    resp = await client.post(
        "/api/v1/reports/generate",
        headers=headers,
        json={"child_id": child_id, "period": "yearly"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "id" in data
    assert "period" in data
    assert "content" in data
    assert "work_count" in data
    assert "honor_count" in data
    assert "generated_at" in data
    assert data["work_count"] == 2
    assert data["honor_count"] == 1


async def test_generate_quarterly_report(client):
    """生成季度报告 period 应为 YYYY-Q1 格式。"""
    headers, child_id = await _setup(client, "13800000102")
    resp = await client.post(
        "/api/v1/reports/generate",
        headers=headers,
        json={"child_id": child_id, "period": "quarterly", "quarter": 1},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["period"].endswith("-Q1")
    assert len(data["period"].split("-")) == 2


async def test_generate_report_invalid_child(client):
    """生成报告时孩子档案不存在应返回 400。"""
    data = await _register_user(client, "13800000103")
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post(
        "/api/v1/reports/generate",
        headers=headers,
        json={"child_id": 99999, "period": "yearly"},
    )
    assert resp.status_code == 400


# ============ 列表 ============

async def test_list_reports(client):
    """列表应包含刚生成的报告。"""
    headers, child_id = await _setup(client, "13800000104")
    gen_resp = await client.post(
        "/api/v1/reports/generate",
        headers=headers,
        json={"child_id": child_id, "period": "yearly"},
    )
    report_id = gen_resp.json()["data"]["id"]

    resp = await client.get("/api/v1/reports", headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["total"] >= 1
    assert any(item["id"] == report_id for item in data["items"])


async def test_list_reports_filter_child(client):
    """按 child_id 筛选报告列表。"""
    headers, child_id = await _setup(client, "13800000105")
    await client.post(
        "/api/v1/reports/generate",
        headers=headers,
        json={"child_id": child_id, "period": "yearly"},
    )

    resp = await client.get(
        "/api/v1/reports", headers=headers, params={"child_id": child_id}
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["total"] == 1
    assert all(item["child_id"] == child_id for item in data["items"])


# ============ 详情 / 删除 ============

async def test_get_report_detail(client):
    """报告详情应包含 work_count 与 honor_count。"""
    headers, child_id = await _setup(client, "13800000106")
    gen_resp = await client.post(
        "/api/v1/reports/generate",
        headers=headers,
        json={"child_id": child_id, "period": "yearly"},
    )
    report_id = gen_resp.json()["data"]["id"]

    resp = await client.get(f"/api/v1/reports/{report_id}", headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["id"] == report_id
    assert data["work_count"] == 2
    assert data["honor_count"] == 1


async def test_get_report_not_found(client):
    """不存在的报告应返回 404。"""
    data = await _register_user(client, "13800000107")
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.get("/api/v1/reports/99999", headers=headers)
    assert resp.status_code == 404


async def test_delete_report(client):
    """删除报告后再次获取应返回 404。"""
    headers, child_id = await _setup(client, "13800000108")
    gen_resp = await client.post(
        "/api/v1/reports/generate",
        headers=headers,
        json={"child_id": child_id, "period": "yearly"},
    )
    report_id = gen_resp.json()["data"]["id"]

    del_resp = await client.delete(f"/api/v1/reports/{report_id}", headers=headers)
    assert del_resp.status_code == 200

    get_resp = await client.get(f"/api/v1/reports/{report_id}", headers=headers)
    assert get_resp.status_code == 404
