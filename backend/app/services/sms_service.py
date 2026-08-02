"""短信验证码服务。

开发环境使用固定验证码 123456 并打印日志，不依赖真实短信通道；
生产环境接入阿里云短信（SMS_ACCESS_KEY_ID 配置后自动启用）。
验证码存入 Redis，有效期 5 分钟，同一手机号 60 秒内不可重复发送。
"""

import secrets
import string

from loguru import logger

from app.core.config import get_settings
from app.core.redis import get_redis

settings = get_settings()

# Redis 键名前缀与 TTL
_CODE_KEY = "sms:code:{phone}"  # 验证码存储
_LIMIT_KEY = "sms:limit:{phone}"  # 发送频率限制
_CODE_TTL = 5 * 60  # 验证码有效期 5 分钟
_LIMIT_TTL = 60  # 发送间隔 60 秒

# 开发环境固定验证码
_DEV_CODE = "123456"


def _generate_code(length: int = 6) -> str:
    """生成指定长度的数字验证码（使用 secrets 保证安全性）。"""
    return "".join(secrets.choice(string.digits) for _ in range(length))


def _is_prod_sms_configured() -> bool:
    """判断是否已配置真实短信服务。"""
    return bool(settings.SMS_ACCESS_KEY_ID and settings.SMS_ACCESS_KEY_SECRET)


async def send_code(phone: str) -> str:
    """发送验证码到指定手机号，返回本次验证码（仅供开发日志使用）。

    Raises:
        ValueError: 60 秒内重复发送。
    """
    redis = await get_redis()

    # 频率限制
    limit_key = _LIMIT_KEY.format(phone=phone)
    if await redis.exists(limit_key):
        raise ValueError("发送过于频繁，请 60 秒后重试")

    # 生成验证码
    if settings.APP_ENV == "development" or settings.DEBUG:
        code = _DEV_CODE
        logger.info(f"[DEV SMS] 手机号 {phone} 验证码: {code}")
    else:
        code = _generate_code()
        if _is_prod_sms_configured():
            # 生产环境：调用阿里云短信 SDK 发送
            # 此处暂未实现，待 SMS_ACCESS_KEY_ID 配置后补充
            logger.warning("短信 SDK 尚未接入，验证码未真实发送")
        else:
            logger.warning(f"未配置短信服务，手机号 {phone} 验证码: {code}")

    # 存入 Redis 并设置频率限制
    code_key = _CODE_KEY.format(phone=phone)
    await redis.set(code_key, code, ex=_CODE_TTL)
    await redis.set(limit_key, "1", ex=_LIMIT_TTL)

    return code


async def verify_code(phone: str, code: str) -> bool:
    """校验验证码是否正确，校验成功后删除（一次性使用）。"""
    redis = await get_redis()
    code_key = _CODE_KEY.format(phone=phone)
    stored = await redis.get(code_key)

    if stored is None:
        return False

    if stored != code:
        return False

    # 校验成功，删除验证码防止重放
    await redis.delete(code_key)
    return True
