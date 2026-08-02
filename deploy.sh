#!/usr/bin/env bash
# 成长印记 · 一键部署脚本
# 用法：
#   ./deploy.sh          # 构建并启动全部服务
#   ./deploy.sh down     # 停止全部服务
#   ./deploy.sh logs     # 查看日志
#   ./deploy.sh restart  # 重启服务
#   ./deploy.sh migrate  # 执行数据库迁移
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE="docker compose"
if ! $COMPOSE version >/dev/null 2>&1; then
    COMPOSE="docker-compose"
fi

case "${1:-up}" in
    up)
        echo "🚀 构建并启动服务..."
        $COMPOSE build
        $COMPOSE up -d
        echo "✅ 服务已启动"
        echo "   API:    http://localhost:8000"
        echo "   Docs:   http://localhost:8000/docs"
        echo "   MySQL:  localhost:3306"
        echo "   Redis:  localhost:6379"
        ;;
    down)
        echo "🛑 停止服务..."
        $COMPOSE down
        echo "✅ 已停止"
        ;;
    logs)
        $COMPOSE logs -f --tail=100
        ;;
    restart)
        echo "🔄 重启服务..."
        $COMPOSE restart
        echo "✅ 已重启"
        ;;
    migrate)
        echo "📦 执行数据库迁移..."
        $COMPOSE exec api alembic upgrade head
        echo "✅ 迁移完成"
        ;;
    status)
        $COMPOSE ps
        ;;
    *)
        echo "用法: $0 {up|down|logs|restart|migrate|status}"
        exit 1
        ;;
esac
