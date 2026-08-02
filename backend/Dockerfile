# ===== 构建阶段 =====
# 使用国内镜像加速源（海外网络可改回 python:3.11-slim）
FROM docker.m.daocloud.io/library/python:3.11-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# 安装系统依赖（构建期）
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc default-libmysqlclient-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir -r requirements.txt

# ===== 运行阶段 =====
FROM docker.m.daocloud.io/library/python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/usr/local/bin:${PATH}"

WORKDIR /app

# 仅安装运行期系统依赖（libmysqlclient）
RUN apt-get update \
    && apt-get install -y --no-install-recommends default-libmysqlclient-dev pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r appuser && useradd -r -g appuser appuser

# 从构建阶段复制已安装的 Python 包
COPY --from=builder /install /usr/local

# 复制应用代码
COPY --chown=appuser:appuser . .

# 复制启动脚本并赋权
COPY --chown=appuser:appuser entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 创建日志与上传目录
RUN mkdir -p logs uploads && chown -R appuser:appuser logs uploads

USER appuser

EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=5 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# 启动脚本：等待 MySQL -> 迁移 -> 种子 -> uvicorn
CMD ["/entrypoint.sh"]
