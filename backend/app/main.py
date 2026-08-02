"""FastAPI 应用入口。"""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from loguru import logger

from app.api.v1 import api_router
from app.core.config import get_settings
from app.core.logging import setup_logging
from app.core.middleware import LoggingMiddleware, SentryMiddleware, setup_sentry
from app.core.redis import close_redis

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期：初始化日志 -> 启动 -> 关闭 Redis。"""
    setup_logging()
    setup_sentry()
    # 生产环境强制校验 JWT 密钥非默认值
    _DEFAULT_JWT_KEY = "please-change-this-to-a-random-secret-key"
    if settings.APP_ENV == "production" and settings.JWT_SECRET_KEY == _DEFAULT_JWT_KEY:
        raise RuntimeError(
            "生产环境禁止使用默认 JWT_SECRET_KEY，请在 .env 中配置随机密钥"
        )
    logger.info(f"启动 {settings.APP_NAME} (env={settings.APP_ENV})")
    yield
    await close_redis()
    logger.info(f"关闭 {settings.APP_NAME}")


app = FastAPI(
    title="Growth Mark API",
    version="1.0.0",
    description=(
        "# 成长印记 · 儿童成长记录 App 后端服务\n\n"
        "## 功能模块\n"
        "- **认证**：手机号验证码注册/登录、JWT 令牌刷新\n"
        "- **孩子档案**：多子女档案管理\n"
        "- **作品时间线**：上传儿童作品（绘画/书法/手工等），按时间线浏览\n"
        "- **荣誉墙**：记录荣誉奖项，按级别筛选\n"
        "- **家庭空间**：家庭成员共享查看\n"
        "- **AI 服务**：图像识别、成长报告生成（通义千问 VL）\n"
        "- **成长报告**：季度/年度汇总报告\n"
        "- **分享服务**：作品/荣誉分享卡片（支持密码保护）\n\n"
        "## 统一响应格式\n"
        "```json\n"
        '{"code": 200, "message": "success", "data": {...}}\n'
        "```\n\n"
        "## 认证方式\n"
        "在请求头中携带 JWT：`Authorization: Bearer <access_token>`\n\n"
        "## 文档\n"
        "- Swagger UI: `/docs`\n"
        "- ReDoc: `/redoc`\n"
        "- OpenAPI JSON: `/openapi.json`"
    ),
    contact={"name": "Growth Mark Team", "email": "dev@growthmark.app"},
    license_info={"name": "MIT", "url": "https://opensource.org/licenses/MIT"},
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    openapi_tags=[
        {"name": "系统", "description": "健康检查与系统信息"},
        {"name": "认证", "description": "用户注册、登录、令牌管理"},
        {"name": "孩子档案", "description": "多子女档案 CRUD"},
        {"name": "作品", "description": "作品时间线管理与查询"},
        {"name": "荣誉", "description": "荣誉奖项记录与统计"},
        {"name": "家庭", "description": "家庭空间成员管理"},
        {"name": "上传", "description": "图片文件上传"},
        {"name": "AI 服务", "description": "图像识别、成长报告、异步任务"},
        {"name": "分享", "description": "分享卡片生成与公开访问"},
        {"name": "成长报告", "description": "季度/年度成长报告"},
    ],
    lifespan=lifespan,
)

# CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 请求日志 + 耗时监控中间件
app.add_middleware(LoggingMiddleware)

# Sentry 异常捕获中间件（未配置 DSN 时自动跳过）
app.add_middleware(SentryMiddleware)

# v1 路由
app.include_router(api_router)

# 静态文件服务（本地存储兜底时用于访问上传的文件）
_uploads_dir = Path("uploads")
_uploads_dir.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(_uploads_dir)), name="uploads")


@app.get(
    "/health",
    tags=["系统"],
    summary="健康检查",
    description="探测服务存活状态，用于负载均衡与容器编排探针。",
    response_description="服务状态",
    responses={
        200: {
            "description": "服务正常",
            "content": {"application/json": {"example": {"status": "ok"}}},
        }
    },
)
async def health_check():
    """健康检查端点。"""
    return {"status": "ok"}
