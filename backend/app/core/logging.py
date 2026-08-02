"""结构化日志配置（基于 loguru）。

特性：
- JSON 格式输出（生产）/ 彩色控制台（开发）
- 按天滚动文件 + 控制台双输出
- 请求 ID 上下文绑定（配合 LoggingMiddleware）
- 慢查询/慢请求告警
"""

import json
import sys
from pathlib import Path
from typing import Any

from loguru import logger

from app.core.config import get_settings

settings = get_settings()


def _json_serializer(record: dict[str, Any]) -> str:
    """生产环境 JSON 格式序列化器。"""
    subset = {
        "timestamp": record["time"].isoformat(),
        "level": record["level"].name,
        "message": record["message"],
        "module": record["module"],
        "function": record["function"],
        "line": record["line"],
    }
    # 合并 extra 字段（排除 loguru 内置字段）
    for key, value in record.get("extra", {}).items():
        if key not in ("__name__", "__record__"):
            subset[key] = value
    if record.get("exception") is not None:
        subset["exception"] = str(record["exception"])
    return json.dumps(subset, ensure_ascii=False, default=str) + "\n"


def _console_formatter(record: dict[str, Any]) -> str:
    """开发环境彩色控制台格式。"""
    request_id = record["extra"].get("request_id", "-")
    return (
        "<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | "
        "<level>{level: <8}</level> | "
        "<cyan>{module}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> | "
        f"<yellow>[{request_id}]</yellow> | "
        "<level>{message}</level>\n"
        "{exception}"
    )


def setup_logging() -> None:
    """初始化全局日志配置。应在应用启动时调用。"""
    logger.remove()  # 清除默认 handler

    log_dir = Path(settings.LOG_DIR)
    log_dir.mkdir(parents=True, exist_ok=True)

    if settings.APP_ENV == "production":
        # 生产环境：JSON 格式 + 文件滚动
        logger.add(
            sys.stdout,
            serialize=False,
            format=_json_serializer,
            level=settings.LOG_LEVEL,
        )
        logger.add(
            log_dir / "app_{time:YYYY-MM-DD}.log",
            rotation="00:00",  # 每天滚动
            retention="30 days",
            compression="zip",
            serialize=False,
            format=_json_serializer,
            level=settings.LOG_LEVEL,
            encoding="utf-8",
        )
        logger.add(
            log_dir / "error_{time:YYYY-MM-DD}.log",
            rotation="00:00",
            retention="90 days",
            compression="zip",
            serialize=False,
            format=_json_serializer,
            level="ERROR",
            encoding="utf-8",
        )
    else:
        # 开发环境：彩色控制台 + 文件
        logger.add(
            sys.stdout,
            format=_console_formatter,
            level=settings.LOG_LEVEL,
            colorize=True,
        )
        logger.add(
            log_dir / "app_{time:YYYY-MM-DD}.log",
            rotation="00:00",
            retention="7 days",
            format=_console_formatter,
            level=settings.LOG_LEVEL,
            encoding="utf-8",
        )

    logger.info("日志系统初始化完成 (env={}, level={})", settings.APP_ENV, settings.LOG_LEVEL)
