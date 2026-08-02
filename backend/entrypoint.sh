#!/bin/sh
set -e

echo "===== 成长印记后端启动 ====="
echo "等待 MySQL 就绪 (${DB_HOST}:${DB_PORT})..."

# 轮询等待 MySQL 可连接
until python -c "
import asyncio
import aiomysql
async def check():
    try:
        conn = await aiomysql.connect(
            host='${DB_HOST}',
            port=${DB_PORT},
            user='${DB_USER}',
            password='${DB_PASSWORD}',
            db='${DB_NAME}',
        )
        conn.close()
        return True
    except Exception:
        return False
asyncio.run(check())
" 2>/dev/null; do
  echo "  MySQL 未就绪，2 秒后重试..."
  sleep 2
done
echo "  MySQL 已就绪。"

echo "执行数据库迁移 (alembic upgrade head)..."
alembic upgrade head

echo "填充种子数据 (python seed.py)..."
python seed.py || echo "  种子数据已存在或失败，跳过。"

echo "启动 FastAPI 服务..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
