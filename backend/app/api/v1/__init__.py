"""API v1 路由聚合。"""

from fastapi import APIRouter

from app.api.v1 import (
    ai,
    auth,
    children,
    families,
    honors,
    reports,
    shares,
    upload,
    works,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(children.router)
api_router.include_router(upload.router)
api_router.include_router(works.router)
api_router.include_router(honors.router)
api_router.include_router(families.router)
api_router.include_router(ai.router)
api_router.include_router(shares.router)
api_router.include_router(reports.router)

# 健康检查端点（Flutter 前端框架会轮询此路径）
@api_router.get("/health", tags=["系统"])
async def api_health():
    return {"status": "ok", "service": "growth-mark-api"}
