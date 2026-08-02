"""HTTP 中间件：请求 ID 追踪、结构化请求日志、耗时监控、Sentry 集成。"""

import time
import uuid
from typing import Awaitable, Callable

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from loguru import logger
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.config import get_settings

settings = get_settings()


class LoggingMiddleware(BaseHTTPMiddleware):
    """请求日志中间件：注入 request_id、记录请求/响应、慢请求告警。"""

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        # 生成或继承上游 request_id
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex[:16]
        request.state.request_id = request_id

        # 绑定到 loguru 上下文
        with logger.contextualize(request_id=request_id):
            start = time.perf_counter()
            client = request.client.host if request.client else "-"
            logger.info(
                "→ {} {} (client={})",
                request.method,
                request.url.path,
                client,
            )

            try:
                response: Response = await call_next(request)
            except Exception:
                elapsed = time.perf_counter() - start
                logger.exception(
                    "✗ {} {} 异常 ({}ms)",
                    request.method,
                    request.url.path,
                    int(elapsed * 1000),
                )
                raise

            elapsed = time.perf_counter() - start
            ms = int(elapsed * 1000)

            # 慢请求告警
            if elapsed > settings.SLOW_REQUEST_THRESHOLD:
                logger.warning(
                    "🐢 慢请求 {} {} -> {} ({}ms, 阈值={}s)",
                    request.method,
                    request.url.path,
                    response.status_code,
                    ms,
                    settings.SLOW_REQUEST_THRESHOLD,
                )
            else:
                logger.info(
                    "← {} {} -> {} ({}ms)",
                    request.method,
                    request.url.path,
                    response.status_code,
                    ms,
                )

            # 响应头注入 request_id 便于客户端排查
            response.headers["X-Request-ID"] = request_id
            return response


class SentryMiddleware(BaseHTTPMiddleware):
    """Sentry 异常捕获中间件（未配置 DSN 时自动跳过）。"""

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if not settings.SENTRY_DSN:
            return await call_next(request)

        try:
            return await call_next(request)
        except Exception as exc:
            import sentry_sdk

            sentry_sdk.set_context(
                "request",
                {
                    "method": request.method,
                    "url": str(request.url),
                    "request_id": getattr(request.state, "request_id", None),
                },
            )
            sentry_sdk.capture_exception(exc)
            logger.exception("未捕获异常: {}", exc)
            return JSONResponse(
                status_code=500,
                content={
                    "code": 500,
                    "message": "服务器内部错误",
                    "request_id": getattr(request.state, "request_id", None),
                },
            )


def setup_sentry() -> None:
    """初始化 Sentry SDK（未配置 DSN 时跳过）。"""
    if not settings.SENTRY_DSN:
        logger.info("SENTRY_DSN 未配置，跳过 Sentry 初始化")
        return

    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.starlette import StarletteIntegration

    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        traces_sample_rate=settings.SENTRY_TRACES_SAMPLE_RATE,
        environment=settings.APP_ENV,
        integrations=[
            StarletteIntegration(),
            FastApiIntegration(),
        ],
    )
    logger.info("Sentry 初始化完成 (env={})", settings.APP_ENV)
