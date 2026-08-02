"""荣誉模型。"""

import enum
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class HonorLevel(str, enum.Enum):
    """荣誉级别。"""

    national = "国家级"
    provincial = "省级"
    municipal = "市级"
    school = "校级"


class Honor(Base):
    """荣誉模型。"""

    __tablename__ = "honors"

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    child_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("children.id"), nullable=False, index=True
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    level: Mapped[HonorLevel] = mapped_column(Enum(HonorLevel), nullable=False)
    category: Mapped[str] = mapped_column(String(50), nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    award_date: Mapped[date] = mapped_column(Date, nullable=False)
    organization: Mapped[str | None] = mapped_column(String(100), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
