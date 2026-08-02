"""Redis 异步客户端。

用于验证码缓存、Token 黑名单、热点数据缓存等场景。
"""

from typing import Optional

import redis.asyncio as redis

from app.core.config import get_settings

settings = get_settings()

# 全局连接池复用，避免每次请求新建连接
_redis_client: Optional[redis.Redis] = None


async def get_redis() -> redis.Redis:
    """获取 Redis 异步客户端单例。

    使用模块级懒加载，首次调用时创建连接池。
    """
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.Redis.from_url(
            settings.redis_url,
            decode_responses=True,
            max_connections=20,
        )
    return _redis_client


async def close_redis() -> None:
    """关闭 Redis 连接池（应用停机时调用）。"""
    global _redis_client
    if _redis_client is not None:
        await _redis_client.aclose()
        _redis_client = None
