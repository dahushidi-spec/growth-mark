"""孩子档案与用户档案接口测试。"""

from datetime import date, timedelta

from tests.test_auth import _register_user


async def _get_token_and_headers(client, phone="13800000030"):
    """注册用户并返回请求头。"""
    data = await _register_user(client, phone)
    return data["access_token"], {"Authorization": f"Bearer {data['access_token']}"}


def _child_payload(name="小明", gender=1, birth_date="2020-06-15"):
    return {"name": name, "gender": gender, "birth_date": birth_date}


# ============ 用户档案 ============

async def test_update_user_profile(client):
    """更新昵称与头像应成功。"""
    token, headers = await _get_token_and_headers(client, "13800000030")
    resp = await client.put(
        "/api/v1/users/me",
        headers=headers,
        json={"nickname": "新昵称", "avatar_url": "http://example.com/a.png"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["nickname"] == "新昵称"
    assert data["avatar_url"] == "http://example.com/a.png"


async def test_update_user_profile_without_token(client):
    """未登录更新用户信息应返回 401。"""
    resp = await client.put(
        "/api/v1/users/me", json={"nickname": "新昵称"}
    )
    assert resp.status_code == 401


# ============ 孩子档案 CRUD ============

async def test_create_child_success(client):
    """创建孩子档案应返回年龄字段。"""
    _, headers = await _get_token_and_headers(client, "13800000031")
    resp = await client.post(
        "/api/v1/children", headers=headers, json=_child_payload()
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["name"] == "小明"
    assert data["gender"] == 1
    assert "岁" in data["age"] or "月" in data["age"] or "天" in data["age"]


async def test_create_child_future_birth_date(client):
    """出生日期晚于今天应返回 422。"""
    _, headers = await _get_token_and_headers(client, "13800000032")
    future = (date.today() + timedelta(days=1)).isoformat()
    resp = await client.post(
        "/api/v1/children",
        headers=headers,
        json=_child_payload(birth_date=future),
    )
    assert resp.status_code == 422


async def test_list_children_multi(client):
    """支持多子女，按出生日期升序返回。"""
    _, headers = await _get_token_and_headers(client, "13800000033")
    await client.post(
        "/api/v1/children",
        headers=headers,
        json=_child_payload(name="老大", birth_date="2018-01-01"),
    )
    await client.post(
        "/api/v1/children",
        headers=headers,
        json=_child_payload(name="老二", birth_date="2020-01-01"),
    )
    resp = await client.get("/api/v1/children", headers=headers)
    assert resp.status_code == 200
    items = resp.json()["data"]
    assert len(items) == 2
    assert items[0]["birth_date"] < items[1]["birth_date"]


async def test_get_child_success(client):
    """获取孩子档案详情应成功。"""
    _, headers = await _get_token_and_headers(client, "13800000034")
    create_resp = await client.post(
        "/api/v1/children", headers=headers, json=_child_payload()
    )
    child_id = create_resp.json()["data"]["id"]
    resp = await client.get(f"/api/v1/children/{child_id}", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["data"]["id"] == child_id


async def test_get_child_not_found(client):
    """不存在的孩子档案应返回 404。"""
    _, headers = await _get_token_and_headers(client, "13800000035")
    resp = await client.get("/api/v1/children/9999", headers=headers)
    assert resp.status_code == 404


async def test_get_child_other_user(client):
    """不能查看他人的孩子档案。"""
    _, headers_a = await _get_token_and_headers(client, "13800000036")
    create_resp = await client.post(
        "/api/v1/children", headers=headers_a, json=_child_payload()
    )
    child_id = create_resp.json()["data"]["id"]

    _, headers_b = await _get_token_and_headers(client, "13800000037")
    resp = await client.get(f"/api/v1/children/{child_id}", headers=headers_b)
    assert resp.status_code == 404


async def test_update_child_success(client):
    """更新孩子档案应成功。"""
    _, headers = await _get_token_and_headers(client, "13800000038")
    create_resp = await client.post(
        "/api/v1/children", headers=headers, json=_child_payload()
    )
    child_id = create_resp.json()["data"]["id"]
    resp = await client.put(
        f"/api/v1/children/{child_id}",
        headers=headers,
        json={"name": "小红", "gender": 0},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["name"] == "小红"
    assert data["gender"] == 0


async def test_delete_child_success(client):
    """删除孩子档案后列表应不再包含。"""
    _, headers = await _get_token_and_headers(client, "13800000039")
    create_resp = await client.post(
        "/api/v1/children", headers=headers, json=_child_payload()
    )
    child_id = create_resp.json()["data"]["id"]
    resp = await client.delete(f"/api/v1/children/{child_id}", headers=headers)
    assert resp.status_code == 200

    list_resp = await client.get("/api/v1/children", headers=headers)
    assert len(list_resp.json()["data"]) == 0


async def test_child_age_calculation_infant(client):
    """新生儿年龄应返回天数或月数。"""
    _, headers = await _get_token_and_headers(client, "13800000040")
    recent = (date.today() - timedelta(days=10)).isoformat()
    resp = await client.post(
        "/api/v1/children",
        headers=headers,
        json=_child_payload(birth_date=recent),
    )
    age = resp.json()["data"]["age"]
    assert "天" in age


async def test_child_age_calculation_years(client):
    """大孩子年龄应返回岁数。"""
    _, headers = await _get_token_and_headers(client, "13800000041")
    resp = await client.post(
        "/api/v1/children",
        headers=headers,
        json=_child_payload(birth_date="2015-06-15"),
    )
    age = resp.json()["data"]["age"]
    assert "岁" in age
