"""数据库引擎与会话配置。

SQLAlchemy 2.0 异步风格，使用 aiomysql 驱动连接 MySQL。
"""

from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import declarative_base

from app.core.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.database_url,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    pool_recycle=3600,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)

# 所有模型的声明性基类
Base = declarative_base()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """异步数据库会话依赖生成器。

    自动处理提交与回滚，请求结束关闭会话。
    """
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
