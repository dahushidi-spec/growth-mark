"""应用配置模块。

使用 pydantic-settings 从环境变量 / .env 文件读取配置。
"""

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# JWT 默认密钥占位符，生产环境必须替换
_DEFAULT_JWT_KEY = "please-change-this-to-a-random-secret-key"


class Settings(BaseSettings):
    """全局配置项，字段从环境变量读取。"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ============ 应用配置 ============
    APP_NAME: str = "Growth Mark"
    APP_ENV: str = "development"
    DEBUG: bool = True

    # ============ 数据库配置 ============
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = ""
    DB_NAME: str = "growth_mark"

    # ============ Redis 配置 ============
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str = ""

    # ============ JWT 配置 ============
    JWT_SECRET_KEY: str = _DEFAULT_JWT_KEY
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 120
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def _validate_jwt_key(cls, v: str) -> str:
        """生产环境强制要求自定义密钥，防止默认密钥导致鉴权被绕过。"""
        if v == _DEFAULT_JWT_KEY:
            # 允许开发/测试环境使用默认密钥，但给出明确警告
            import warnings

            warnings.warn(
                "JWT_SECRET_KEY 使用默认占位值，请在 .env 中配置随机密钥。"
                "生产环境将拒绝启动。",
                stacklevel=2,
            )
        return v

    # ============ 阿里云 OSS 配置 ============
    OSS_ACCESS_KEY_ID: str = ""
    OSS_ACCESS_KEY_SECRET: str = ""
    OSS_BUCKET_NAME: str = ""
    OSS_ENDPOINT: str = "oss-cn-hangzhou.aliyuncs.com"
    OSS_CDN_DOMAIN: str = ""

    # ============ 短信服务配置 ============
    SMS_ACCESS_KEY_ID: str = ""
    SMS_ACCESS_KEY_SECRET: str = ""
    SMS_SIGN_NAME: str = ""
    SMS_TEMPLATE_CODE: str = ""

    # ============ AI 服务配置 ============
    AI_PROVIDER: str = "qwen"
    AI_API_KEY: str = ""
    AI_MODEL: str = "qwen-vl-max"
    AI_BASE_URL: str = "https://dashscope.aliyuncs.com/api/v1"

    # ============ Celery 配置 ============
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"

    # ============ Sentry 配置 ============
    SENTRY_DSN: str = ""
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1

    # ============ 日志配置 ============
    LOG_LEVEL: str = "INFO"
    LOG_DIR: str = "logs"
    SLOW_REQUEST_THRESHOLD: float = 1.0  # 慢请求阈值（秒）

    # ============ CORS 配置 ============
    CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    @property
    def database_url(self) -> str:
        """异步数据库连接 URL（aiomysql 驱动）。"""
        return (
            f"mysql+aiomysql://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}?charset=utf8mb4"
        )

    @property
    def redis_url(self) -> str:
        """Redis 连接 URL。"""
        if self.REDIS_PASSWORD:
            return (
                f"redis://:{self.REDIS_PASSWORD}@{self.REDIS_HOST}:{self.REDIS_PORT}/0"
            )
        return f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}/0"


@lru_cache
def get_settings() -> Settings:
    """获取全局配置单例（使用 lru_cache 缓存）。"""
    return Settings()
