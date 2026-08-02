"""日志与中间件测试：结构化日志初始化 + 请求 ID 追踪 + 慢请求告警。"""

import json
from unittest.mock import patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.logging import _console_formatter, _json_serializer, setup_logging
from app.core.middleware import LoggingMiddleware, SentryMiddleware


class TestLoggingSetup:
    """日志初始化测试。"""

    def test_setup_logging_dev(self):
        """开发环境初始化不应抛异常。"""
        with patch("app.core.logging.settings") as mock_settings:
            mock_settings.APP_ENV = "development"
            mock_settings.LOG_LEVEL = "INFO"
            mock_settings.LOG_DIR = "logs"
            setup_logging()  # 不抛异常即通过

    def test_setup_logging_prod(self):
        """生产环境初始化不应抛异常。"""
        with patch("app.core.logging.settings") as mock_settings:
            mock_settings.APP_ENV = "production"
            mock_settings.LOG_LEVEL = "INFO"
            mock_settings.LOG_DIR = "logs"
            setup_logging()


class TestJsonSerializer:
    """JSON 序列化器测试。"""

    def test_json_serializer_basic(self):
        """JSON 序列化应包含核心字段。"""
        record = {
            "time": _mock_time(),
            "level": _mock_level("INFO"),
            "message": "测试消息",
            "module": "test_module",
            "function": "test_func",
            "line": 42,
            "extra": {"request_id": "abc123"},
            "exception": None,
        }
        result = _json_serializer(record)
        data = json.loads(result)
        assert data["message"] == "测试消息"
        assert data["module"] == "test_module"
        assert data["line"] == 42
        assert data["request_id"] == "abc123"

    def test_json_serializer_with_exception(self):
        """异常信息应被序列化。"""
        record = {
            "time": _mock_time(),
            "level": _mock_level("ERROR"),
            "message": "出错了",
            "module": "m",
            "function": "f",
            "line": 1,
            "extra": {},
            "exception": ValueError("测试异常"),
        }
        result = _json_serializer(record)
        data = json.loads(result)
        assert "测试异常" in data["exception"]


class TestConsoleFormatter:
    """控制台格式化器测试。"""

    def test_console_formatter_contains_request_id(self):
        """格式字符串应包含 request_id 占位。"""
        record = {"extra": {"request_id": "req-001"}}
        fmt = _console_formatter(record)
        assert "req-001" in fmt
        assert "{message}" in fmt


class _MockTime:
    def isoformat(self):
        return "2026-01-01T00:00:00"


class _MockLevel:
    def __init__(self, name):
        self.name = name


def _mock_time():
    return _MockTime()


def _mock_level(name):
    return _MockLevel(name)


@pytest.mark.asyncio
class TestLoggingMiddleware:
    """LoggingMiddleware 集成测试。"""

    async def test_request_id_injected_in_response(self):
        """响应头应包含 X-Request-ID。"""
        app = FastAPI()
        app.add_middleware(LoggingMiddleware)

        @app.get("/ping")
        async def ping():
            return {"pong": True}

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.get("/ping")
        assert resp.status_code == 200
        assert "x-request-id" in resp.headers
        assert len(resp.headers["x-request-id"]) > 0

    async def test_request_id_inherited_from_header(self):
        """客户端传入的 X-Request-ID 应被继承。"""
        app = FastAPI()
        app.add_middleware(LoggingMiddleware)

        @app.get("/ping")
        async def ping():
            return {"pong": True}

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.get("/ping", headers={"X-Request-ID": "client-rid-123"})
        assert resp.headers["x-request-id"] == "client-rid-123"


@pytest.mark.asyncio
class TestSentryMiddleware:
    """SentryMiddleware 测试。"""

    async def test_sentry_skipped_when_no_dsn(self):
        """未配置 DSN 时应直接放行。"""
        app = FastAPI()
        app.add_middleware(SentryMiddleware)

        @app.get("/ok")
        async def ok():
            return {"ok": True}

        with patch("app.core.middleware.settings") as mock_settings:
            mock_settings.SENTRY_DSN = ""
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                resp = await ac.get("/ok")
            assert resp.status_code == 200
