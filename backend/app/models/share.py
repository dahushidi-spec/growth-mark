"""分享与成长报告模型。"""

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Share(Base):
    """分享记录模型。"""

    __tablename__ = "shares"

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False, index=True
    )
    work_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("works.id"), nullable=True
    )
    honor_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("honors.id"), nullable=True
    )
    share_type: Mapped[str] = mapped_column(String(50), nullable=False)
    share_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    password: Mapped[str | None] = mapped_column(String(100), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class GrowthReport(Base):
    """AI 生成的成长报告模型。"""

    __tablename__ = "growth_reports"

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    child_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("children.id"), nullable=False, index=True
    )
    period: Mapped[str] = mapped_column(String(20), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    generated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
