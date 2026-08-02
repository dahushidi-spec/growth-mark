"""家庭空间服务接口测试：创建、加入、成员管理。"""

from tests.test_auth import _register_user


async def _register(client, phone):
    """注册并返回 headers。"""
    data = await _register_user(client, phone)
    return {"Authorization": f"Bearer {data['access_token']}"}


# ============ 创建家庭 ============

async def test_create_family_success(client):
    """创建家庭应生成 6 位邀请码，创建者成为 creator。"""
    headers = await _register(client, "13800000090")
    resp = await client.post(
        "/api/v1/families", headers=headers, json={"name": "我们家"}
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["name"] == "我们家"
    assert len(data["invite_code"]) == 6
    assert len(data["members"]) == 1
    assert data["members"][0]["role"] == "creator"


async def test_create_family_without_token(client):
    """未登录创建家庭应返回 401。"""
    resp = await client.post("/api/v1/families", json={"name": "test"})
    assert resp.status_code == 401


# ============ 加入家庭 ============

async def test_join_family_success(client):
    """通过邀请码加入家庭应成功，角色为 member。"""
    headers_a = await _register(client, "13800000091")
    create_resp = await client.post(
        "/api/v1/families", headers=headers_a, json={"name": "家庭"}
    )
    invite_code = create_resp.json()["data"]["invite_code"]

    headers_b = await _register(client, "13800000092")
    resp = await client.post(
        "/api/v1/families/join", headers=headers_b, json={"invite_code": invite_code}
    )
    assert resp.status_code == 200
    members = resp.json()["data"]["members"]
    assert len(members) == 2
    assert any(m["role"] == "member" for m in members)


async def test_join_family_invalid_code(client):
    """无效邀请码应返回 404。"""
    headers = await _register(client, "13800000093")
    resp = await client.post(
        "/api/v1/families/join", headers=headers, json={"invite_code": "XXXXXX"}
    )
    assert resp.status_code == 404


async def test_join_family_already_member(client):
    """已是成员再次加入应直接返回，不报错。"""
    headers = await _register(client, "13800000094")
    create_resp = await client.post(
        "/api/v1/families", headers=headers, json={"name": "家庭"}
    )
    invite_code = create_resp.json()["data"]["invite_code"]

    resp = await client.post(
        "/api/v1/families/join", headers=headers, json={"invite_code": invite_code}
    )
    assert resp.status_code == 200
    assert len(resp.json()["data"]["members"]) == 1


# ============ 成员管理 ============

async def test_list_members(client):
    """获取家庭成员列表需为该家庭成员。"""
    headers_a = await _register(client, "13800000095")
    create_resp = await client.post(
        "/api/v1/families", headers=headers_a, json={"name": "家庭"}
    )
    family_id = create_resp.json()["data"]["id"]

    resp = await client.get(
        f"/api/v1/families/{family_id}/members", headers=headers_a
    )
    assert resp.status_code == 200
    assert len(resp.json()["data"]) == 1


async def test_list_members_non_member(client):
    """非家庭成员查看成员列表应返回 403。"""
    headers_a = await _register(client, "13800000096")
    create_resp = await client.post(
        "/api/v1/families", headers=headers_a, json={"name": "家庭"}
    )
    family_id = create_resp.json()["data"]["id"]

    headers_b = await _register(client, "13800000097")
    resp = await client.get(
        f"/api/v1/families/{family_id}/members", headers=headers_b
    )
    assert resp.status_code == 403


async def test_remove_member_by_creator(client):
    """创建者可移除普通成员。"""
    headers_a = await _register(client, "13800000098")
    create_resp = await client.post(
        "/api/v1/families", headers=headers_a, json={"name": "家庭"}
    )
    family_id = create_resp.json()["data"]["id"]
    invite_code = create_resp.json()["data"]["invite_code"]

    headers_b = await _register(client, "13800000099")
    await client.post(
        "/api/v1/families/join", headers=headers_b, json={"invite_code": invite_code}
    )

    # 获取成员B的user_id
    members_resp = await client.get(
        f"/api/v1/families/{family_id}/members", headers=headers_a
    )
    member_b = [m for m in members_resp.json()["data"] if m["role"] == "member"][0]

    resp = await client.delete(
        f"/api/v1/families/{family_id}/members/{member_b['user_id']}",
        headers=headers_a,
    )
    assert resp.status_code == 200


async def test_remove_member_by_member_forbidden(client):
    """普通成员不能移除他人。"""
    headers_a = await _register(client, "13800000100")
    create_resp = await client.post(
        "/api/v1/families", headers=headers_a, json={"name": "家庭"}
    )
    family_id = create_resp.json()["data"]["id"]
    invite_code = create_resp.json()["data"]["invite_code"]

    headers_b = await _register(client, "13800000101")
    headers_c = await _register(client, "13800000102")
    await client.post(
        "/api/v1/families/join", headers=headers_b, json={"invite_code": invite_code}
    )
    await client.post(
        "/api/v1/families/join", headers=headers_c, json={"invite_code": invite_code}
    )

    members_resp = await client.get(
        f"/api/v1/families/{family_id}/members", headers=headers_a
    )
    # 简化：B 尝试移除 C（B 是普通成员，无权操作）
    members = members_resp.json()["data"]
    creator = [m for m in members if m["role"] == "creator"][0]
    members_non_creator = [m for m in members if m["user_id"] != creator["user_id"]]
    member_c = members_non_creator[1]  # 第二个加入的非创建者

    resp = await client.delete(
        f"/api/v1/families/{family_id}/members/{member_c['user_id']}",
        headers=headers_b,
    )
    assert resp.status_code == 403


async def test_remove_creator_forbidden(client):
    """不能移除家庭创建者。"""
    headers_a = await _register(client, "13800000103")
    create_resp = await client.post(
        "/api/v1/families", headers=headers_a, json={"name": "家庭"}
    )
    family_id = create_resp.json()["data"]["id"]

    members_resp = await client.get(
        f"/api/v1/families/{family_id}/members", headers=headers_a
    )
    creator = members_resp.json()["data"][0]

    resp = await client.delete(
        f"/api/v1/families/{family_id}/members/{creator['user_id']}",
        headers=headers_a,
    )
    assert resp.status_code == 400
