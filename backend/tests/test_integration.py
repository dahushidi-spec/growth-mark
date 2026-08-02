"""Week 5 联调集成测试：端到端业务流程验证。

覆盖 T01-T05 五个联调场景：
- T01 认证流程：发码 -> 注册 -> 登录 -> 刷新 -> /me
- T02 作品上传：创建孩子 -> 上传图片 -> AI 识别 -> 保存作品 -> 时间线
- T03 荣誉：创建荣誉 -> 统计 -> 列表筛选 -> 详情 -> 删除
- T04 家庭：创建家庭 -> 邀请加入 -> 成员列表 -> 移除
- T05 报告与分享：生成报告 -> 列表 -> 创建分享 -> 验证访问
"""

import pytest

from app.core.redis import get_redis

# Redis 键名（与 sms_service 保持一致）
_SMS_CODE_KEY = "sms:code:{phone}"

# 全局 stub 实例引用（由 fixture 初始化）
_stub_ref: dict[str, object] = {}


@pytest.fixture(autouse=True)
def _stub_redis(monkeypatch):
    """用内存字典 stub Redis，避免依赖真实 Redis 服务。

    sms_service 使用以下 Redis 方法：exists / set / get / delete
    """

    store: dict[str, str] = {}

    class _StubRedis:
        async def get(self, key: str) -> str | None:
            return store.get(key)

        async def set(self, key: str, value: str, ex: int | None = None) -> None:
            store[key] = value

        async def setex(self, key: str, ttl: int, value: str) -> None:
            store[key] = value

        async def exists(self, key: str) -> int:
            return 1 if key in store else 0

        async def delete(self, *keys: str) -> int:
            deleted = 0
            for k in keys:
                if k in store:
                    del store[k]
                    deleted += 1
            return deleted

        async def ping(self) -> str:
            return "PONG"

        async def close(self) -> None:
            pass

    stub = _StubRedis()
    _stub_ref["stub"] = stub

    async def _async_get_redis():
        return stub

    # patch get_redis 返回 stub（覆盖 core 与 sms_service 两处引用）
    monkeypatch.setattr("app.core.redis.get_redis", _async_get_redis)
    monkeypatch.setattr("app.services.sms_service.get_redis", _async_get_redis)

    async def _override():
        return stub

    from app.main import app

    app.dependency_overrides[get_redis] = _override
    yield
    app.dependency_overrides.pop(get_redis, None)
    _stub_ref.pop("stub", None)


async def _get_code(phone: str) -> str | None:
    """从 stub Redis 中读取验证码。"""
    stub = _stub_ref.get("stub")
    if stub is None:
        return None
    return await stub.get(_SMS_CODE_KEY.format(phone=phone))


@pytest.mark.asyncio
class TestT01AuthFlow:
    """T01 认证流程联调：发码 -> 注册 -> 登录 -> 刷新 -> /me。"""

    async def test_full_auth_flow(self, client):
        phone = "13800138001"
        password = "pass1234"
        nickname = "联调测试用户"

        # 1. 发送验证码
        resp = await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        assert resp.status_code == 200
        assert resp.json()["data"]["sent"] is True

        # 从 Redis stub 中取出验证码
        code = await _get_code(phone)
        assert code is not None

        # 2. 注册
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "verification_code": code,
                "password": password,
                "nickname": nickname,
            },
        )
        assert resp.status_code == 200
        reg_data = resp.json()["data"]
        access_token = reg_data["access_token"]
        refresh_token = reg_data["refresh_token"]
        assert reg_data["user"]["nickname"] == nickname
        user_id = reg_data["user"]["id"]

        # 3. 登录
        resp = await client.post(
            "/api/v1/auth/login",
            json={"phone": phone, "password": password},
        )
        assert resp.status_code == 200
        login_data = resp.json()["data"]
        assert login_data["user"]["id"] == user_id

        # 4. 刷新令牌
        resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert resp.status_code == 200
        assert "access_token" in resp.json()["data"]

        # 5. 获取当前用户
        resp = await client.get(
            "/api/v1/auth/me", headers={"Authorization": f"Bearer {access_token}"}
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["phone"] == phone

    async def test_sms_rate_limit(self, client):
        """60 秒内重复发送验证码应被限流。"""
        phone = "13800138002"
        resp1 = await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        assert resp1.status_code == 200

        resp2 = await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        assert resp2.status_code == 429

    async def test_login_wrong_password(self, client):
        """错误密码登录应返回 401。"""
        phone = "13800138003"
        await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        code = await _get_code(phone)

        await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "verification_code": code,
                "password": "correct123",
                "nickname": "测试",
            },
        )

        resp = await client.post(
            "/api/v1/auth/login",
            json={"phone": phone, "password": "wrong_password"},
        )
        assert resp.status_code == 401


@pytest.mark.asyncio
class TestT02WorkUploadFlow:
    """T02 作品上传联调：孩子档案 -> 作品 CRUD -> 时间线。"""

    async def _register_and_get_token(self, client, phone: str) -> str:
        """辅助：注册并返回 access_token。"""
        await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        code = await _get_code(phone)
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "verification_code": code,
                "password": "pass1234",
                "nickname": "上传测试",
            },
        )
        return resp.json()["data"]["access_token"]

    async def test_work_full_flow(self, client):
        token = await self._register_and_get_token(client, "13800138010")
        headers = {"Authorization": f"Bearer {token}"}

        # 1. 创建孩子档案
        resp = await client.post(
            "/api/v1/children",
            json={
                "name": "小测试",
                "gender": 1,
                "birth_date": "2020-05-15",
            },
            headers=headers,
        )
        assert resp.status_code == 200
        child_id = resp.json()["data"]["id"]

        # 2. 创建作品
        resp = await client.post(
            "/api/v1/works",
            json={
                "title": "我的第一幅画",
                "category": "绘画",
                "description": "五彩的彩虹",
                "image_url": "http://example.com/img1.jpg",
                "thumbnail_url": "http://example.com/img1_thumb.jpg",
                "created_date": "2026-06-01",
                "child_id": child_id,
                "tags": ["彩虹", "水彩"],
            },
            headers=headers,
        )
        assert resp.status_code == 200
        work_id = resp.json()["data"]["id"]
        assert resp.json()["data"]["title"] == "我的第一幅画"

        # 3. 查询时间线
        resp = await client.get(
            "/api/v1/works/timeline",
            params={"child_id": child_id},
            headers=headers,
        )
        assert resp.status_code == 200
        items = resp.json()["data"]["items"]
        assert len(items) >= 1
        assert items[0]["title"] == "我的第一幅画"

        # 4. 获取作品详情
        resp = await client.get(f"/api/v1/works/{work_id}", headers=headers)
        assert resp.status_code == 200
        detail = resp.json()["data"]
        assert detail["id"] == work_id
        # tags 应返回 [{tag_name, is_ai_generated, id}]
        tag_names = [t["tag_name"] for t in detail["tags"]]
        assert "彩虹" in tag_names

        # 5. 更新作品
        resp = await client.put(
            f"/api/v1/works/{work_id}",
            json={"title": "我的第一幅画（修订）"},
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["title"] == "我的第一幅画（修订）"

        # 6. 删除作品
        resp = await client.delete(f"/api/v1/works/{work_id}", headers=headers)
        assert resp.status_code == 200

        # 7. 再次查询详情应 404
        resp = await client.get(f"/api/v1/works/{work_id}", headers=headers)
        assert resp.status_code == 404


@pytest.mark.asyncio
class TestT03HonorFlow:
    """T03 荣誉与详情联调。"""

    async def _register_and_get_token(self, client, phone: str) -> tuple[str, int]:
        """辅助：注册并返回 (access_token, child_id)。"""
        await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        code = await _get_code(phone)
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "verification_code": code,
                "password": "pass1234",
                "nickname": "荣誉测试",
            },
        )
        token = resp.json()["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        resp = await client.post(
            "/api/v1/children",
            json={"name": "小荣誉", "gender": 0, "birth_date": "2019-03-20"},
            headers=headers,
        )
        return token, resp.json()["data"]["id"]

    async def test_honor_full_flow(self, client):
        token, child_id = await self._register_and_get_token(client, "13800138020")
        headers = {"Authorization": f"Bearer {token}"}

        # 创建 3 个不同级别的荣誉
        levels = ["国家级", "省级", "校级"]
        for i, level in enumerate(levels):
            resp = await client.post(
                "/api/v1/honors",
                json={
                    "title": f"奖项{i+1}",
                    "level": level,
                    "category": "学科",
                    "award_date": "2026-06-01",
                    "child_id": child_id,
                },
                headers=headers,
            )
            assert resp.status_code == 200

        # 统计：总数 3，本年 3，市级以上 2
        resp = await client.get("/api/v1/honors/stats", headers=headers)
        assert resp.status_code == 200
        stats = resp.json()["data"]
        assert stats["total"] == 3
        assert stats["this_year"] == 3
        assert stats["high_level"] == 2

        # 级别筛选：国家级 1 个
        resp = await client.get(
            "/api/v1/honors",
            params={"level": "国家级"},
            headers=headers,
        )
        assert resp.status_code == 200
        assert len(resp.json()["data"]["items"]) == 1

        # 详情
        honor_id = resp.json()["data"]["items"][0]["id"]
        resp = await client.get(f"/api/v1/honors/{honor_id}", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["level"] == "国家级"

        # 删除
        resp = await client.delete(f"/api/v1/honors/{honor_id}", headers=headers)
        assert resp.status_code == 200

        # 统计应更新
        resp = await client.get("/api/v1/honors/stats", headers=headers)
        assert resp.json()["data"]["total"] == 2


@pytest.mark.asyncio
class TestT04FamilyFlow:
    """T04 家庭空间联调：创建 -> 邀请加入 -> 成员管理。"""

    async def _register(self, client, phone: str, nickname: str) -> str:
        await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        code = await _get_code(phone)
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "verification_code": code,
                "password": "pass1234",
                "nickname": nickname,
            },
        )
        return resp.json()["data"]["access_token"]

    async def test_family_full_flow(self, client):
        creator_token = await self._register(client, "13800138030", "创建者")
        member_token = await self._register(client, "13800138031", "成员A")
        creator_headers = {"Authorization": f"Bearer {creator_token}"}
        member_headers = {"Authorization": f"Bearer {member_token}"}

        # 1. 创建家庭
        resp = await client.post(
            "/api/v1/families",
            json={"name": "联调之家"},
            headers=creator_headers,
        )
        assert resp.status_code == 200
        family = resp.json()["data"]
        family_id = family["id"]
        invite_code = family["invite_code"]
        assert len(family["members"]) == 1
        assert family["members"][0]["role"] == "creator"

        # 2. 成员 A 通过邀请码加入
        resp = await client.post(
            "/api/v1/families/join",
            json={"invite_code": invite_code},
            headers=member_headers,
        )
        assert resp.status_code == 200
        assert len(resp.json()["data"]["members"]) == 2

        # 3. 列出家庭成员（创建者视角）
        resp = await client.get(
            f"/api/v1/families/{family_id}/members", headers=creator_headers
        )
        assert resp.status_code == 200
        assert len(resp.json()["data"]) == 2

        # 4. 成员访问家庭（权限校验）
        resp = await client.get(
            f"/api/v1/families/{family_id}/members", headers=member_headers
        )
        assert resp.status_code == 200

        # 5. 创建者移除成员 A
        member_a_id = next(
            m["user_id"] for m in resp.json()["data"] if m["role"] == "member"
        )
        resp = await client.delete(
            f"/api/v1/families/{family_id}/members/{member_a_id}",
            headers=creator_headers,
        )
        assert resp.status_code == 200

        # 6. 移除后成员 A 不能再访问
        resp = await client.get(
            f"/api/v1/families/{family_id}/members", headers=member_headers
        )
        assert resp.status_code == 403

    async def test_invalid_invite_code(self, client):
        """无效邀请码加入应返回 404。"""
        token = await self._register(client, "13800138032", "用户")
        resp = await client.post(
            "/api/v1/families/join",
            json={"invite_code": "INVAL1"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404


@pytest.mark.asyncio
class TestT05ReportAndShareFlow:
    """T05 AI 与分享联调：报告生成 + 分享卡片。"""

    async def _setup(self, client, phone: str) -> tuple[str, int, int]:
        """辅助：注册 -> 创建孩子 -> 创建作品 -> 返回 (token, child_id, work_id)。"""
        await client.post("/api/v1/auth/sms/send", json={"phone": phone})
        code = await _get_code(phone)
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "verification_code": code,
                "password": "pass1234",
                "nickname": "分享测试",
            },
        )
        token = resp.json()["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        resp = await client.post(
            "/api/v1/children",
            json={"name": "小分享", "gender": 1, "birth_date": "2020-01-01"},
            headers=headers,
        )
        child_id = resp.json()["data"]["id"]

        resp = await client.post(
            "/api/v1/works",
            json={
                "title": "分享作品",
                "category": "绘画",
                "image_url": "http://example.com/share.jpg",
                "created_date": "2026-06-01",
                "child_id": child_id,
            },
            headers=headers,
        )
        work_id = resp.json()["data"]["id"]
        return token, child_id, work_id

    async def test_report_flow(self, client):
        token, child_id, _ = await self._setup(client, "13800138040")
        headers = {"Authorization": f"Bearer {token}"}

        # 生成年度报告
        resp = await client.post(
            "/api/v1/reports/generate",
            json={
                "child_id": child_id,
                "period": "yearly",
                "year": 2026,
            },
            headers=headers,
        )
        assert resp.status_code == 200
        report = resp.json()["data"]
        assert report["period"] == "2026"
        assert report["work_count"] == 1
        assert len(report["content"]) > 0
        report_id = report["id"]

        # 列表
        resp = await client.get("/api/v1/reports", headers=headers)
        assert resp.status_code == 200
        assert len(resp.json()["data"]["items"]) == 1

        # 详情
        resp = await client.get(f"/api/v1/reports/{report_id}", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["work_count"] == 1

        # 删除
        resp = await client.delete(f"/api/v1/reports/{report_id}", headers=headers)
        assert resp.status_code == 200

    async def test_share_flow(self, client):
        token, child_id, work_id = await self._setup(client, "13800138041")
        headers = {"Authorization": f"Bearer {token}"}

        # 创建分享（无密码）
        resp = await client.post(
            "/api/v1/shares/card",
            json={"work_id": work_id, "share_type": "work"},
            headers=headers,
        )
        assert resp.status_code == 200
        share = resp.json()["data"]
        share_id = share["id"]
        assert share["has_password"] is False
        assert share["share_url"] is not None

        # 公开访问（无密码）
        resp = await client.post(
            f"/api/v1/shares/{share_id}/verify",
            json={},
        )
        assert resp.status_code == 200
        content = resp.json()["data"]
        assert content["title"] == "分享作品"

        # 创建带密码的分享
        resp = await client.post(
            "/api/v1/shares/card",
            json={"work_id": work_id, "share_type": "work", "password": "1234"},
            headers=headers,
        )
        assert resp.status_code == 200
        protected_share_id = resp.json()["data"]["id"]
        assert resp.json()["data"]["has_password"] is True

        # 错误密码
        resp = await client.post(
            f"/api/v1/shares/{protected_share_id}/verify",
            json={"password": "wrong"},
        )
        assert resp.status_code == 403

        # 正确密码
        resp = await client.post(
            f"/api/v1/shares/{protected_share_id}/verify",
            json={"password": "1234"},
        )
        assert resp.status_code == 200

        # 分享列表
        resp = await client.get("/api/v1/shares", headers=headers)
        assert resp.status_code == 200
        assert len(resp.json()["data"]["items"]) == 2

        # 删除分享
        resp = await client.delete(f"/api/v1/shares/{share_id}", headers=headers)
        assert resp.status_code == 200
