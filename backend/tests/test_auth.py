"""认证模块接口测试。

使用内存 SQLite 覆盖数据库依赖，通过 mock 绕过 Redis 验证码依赖。
"""

from unittest.mock import AsyncMock, patch

# ============ 辅助函数 ============

def _register_payload(phone="13800000001", code="123456"):
    return {
        "phone": phone,
        "password": "test123456",
        "nickname": "测试家长",
        "verification_code": code,
    }


async def _register_user(client, phone="13800000001"):
    """注册一个用户并返回登录响应数据。"""
    with patch(
        "app.api.v1.auth.verify_code", new_callable=AsyncMock, return_value=True
    ):
        resp = await client.post("/api/v1/auth/register", json=_register_payload(phone))
    assert resp.status_code == 200, resp.text
    return resp.json()["data"]


# ============ 发送验证码 ============

async def test_send_sms_code_success(client):
    """发送验证码应返回 sent=True。"""
    with patch(
        "app.api.v1.auth.send_code", new_callable=AsyncMock, return_value="123456"
    ):
        resp = await client.post(
            "/api/v1/auth/sms/send", json={"phone": "13800000001"}
        )
    assert resp.status_code == 200
    assert resp.json()["data"]["sent"] is True


async def test_send_sms_code_rate_limited(client):
    """60 秒内重复发送应返回 429。"""
    with patch(
        "app.api.v1.auth.send_code",
        new_callable=AsyncMock,
        side_effect=ValueError("发送过于频繁"),
    ):
        resp = await client.post(
            "/api/v1/auth/sms/send", json={"phone": "13800000001"}
        )
    assert resp.status_code == 429


async def test_send_sms_code_invalid_phone(client):
    """非法手机号应返回 422 校验错误。"""
    resp = await client.post("/api/v1/auth/sms/send", json={"phone": "12345"})
    assert resp.status_code == 422


# ============ 注册 ============

async def test_register_success(client):
    """注册成功应返回令牌与用户信息。"""
    with patch(
        "app.api.v1.auth.verify_code", new_callable=AsyncMock, return_value=True
    ):
        resp = await client.post(
            "/api/v1/auth/register", json=_register_payload()
        )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["phone"] == "13800000001"
    assert data["user"]["nickname"] == "测试家长"


async def test_register_invalid_code(client):
    """验证码错误应返回 400。"""
    with patch(
        "app.api.v1.auth.verify_code", new_callable=AsyncMock, return_value=False
    ):
        resp = await client.post(
            "/api/v1/auth/register", json=_register_payload()
        )
    assert resp.status_code == 400
    assert "验证码" in resp.json()["detail"]


async def test_register_duplicate_phone(client):
    """重复手机号注册应返回 400。"""
    await _register_user(client, "13800000002")
    with patch(
        "app.api.v1.auth.verify_code", new_callable=AsyncMock, return_value=True
    ):
        resp = await client.post(
            "/api/v1/auth/register", json=_register_payload("13800000002")
        )
    assert resp.status_code == 400
    assert "已注册" in resp.json()["detail"]


async def test_register_short_password(client):
    """密码过短应返回 422。"""
    payload = _register_payload()
    payload["password"] = "123"
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


# ============ 登录 ============

async def test_login_success(client):
    """正确凭据登录应返回令牌与用户。"""
    await _register_user(client, "13800000003")
    resp = await client.post(
        "/api/v1/auth/login",
        json={"phone": "13800000003", "password": "test123456"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "access_token" in data
    assert data["user"]["phone"] == "13800000003"


async def test_login_wrong_password(client):
    """密码错误应返回 401。"""
    await _register_user(client, "13800000004")
    resp = await client.post(
        "/api/v1/auth/login",
        json={"phone": "13800000004", "password": "wrong_password"},
    )
    assert resp.status_code == 401


async def test_login_nonexistent_user(client):
    """不存在的手机号登录应返回 401。"""
    resp = await client.post(
        "/api/v1/auth/login",
        json={"phone": "13999999999", "password": "test123456"},
    )
    assert resp.status_code == 401


# ============ 刷新令牌 ============

async def test_refresh_success(client):
    """有效刷新令牌应换发新令牌。"""
    data = await _register_user(client, "13800000005")
    resp = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": data["refresh_token"]},
    )
    assert resp.status_code == 200
    new_data = resp.json()["data"]
    assert "access_token" in new_data
    assert new_data["user"]["phone"] == "13800000005"


async def test_refresh_with_access_token_fails(client):
    """使用 access_token 刷新应失败（类型不匹配）。"""
    data = await _register_user(client, "13800000006")
    resp = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": data["access_token"]},
    )
    assert resp.status_code == 401


async def test_refresh_invalid_token(client):
    """无效刷新令牌应返回 401。"""
    resp = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "invalid.token.string"},
    )
    assert resp.status_code == 401


# ============ 获取当前用户 ============

async def test_me_success(client):
    """携带有效令牌应返回当前用户信息。"""
    data = await _register_user(client, "13800000007")
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {data['access_token']}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["phone"] == "13800000007"


async def test_me_without_token(client):
    """未携带令牌应返回 401。"""
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 401


async def test_me_with_invalid_token(client):
    """无效令牌应返回 401。"""
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer invalid.token.here"},
    )
    assert resp.status_code == 401


# ============ 令牌类型校验 ============

async def test_access_token_has_correct_type(client):
    """access_token 解码后 type 应为 access。"""
    import jwt

    from app.core.config import get_settings

    settings = get_settings()
    data = await _register_user(client, "13800000008")
    payload = jwt.decode(
        data["access_token"], settings.JWT_SECRET_KEY, algorithms=["HS256"]
    )
    assert payload["type"] == "access"
    assert payload["sub"] is not None


async def test_refresh_token_has_correct_type(client):
    """refresh_token 解码后 type 应为 refresh。"""
    import jwt

    from app.core.config import get_settings

    settings = get_settings()
    data = await _register_user(client, "13800000009")
    payload = jwt.decode(
        data["refresh_token"], settings.JWT_SECRET_KEY, algorithms=["HS256"]
    )
    assert payload["type"] == "refresh"
