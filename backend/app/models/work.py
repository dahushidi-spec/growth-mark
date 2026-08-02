"""作品与作品标签模型。"""

import enum
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class WorkCategory(str, enum.Enum):
    """作品分类。"""

    painting = "绘画"
    calligraphy = "书法"
    craft = "手工"
    music = "音乐"
    writing = "写作"
    other = "其他"


class Work(Base):
    """成长作品模型。"""

    __tablename__ = "works"

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
    family_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("families.id"), nullable=True
    )
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    category: Mapped[WorkCategory] = mapped_column(Enum(WorkCategory), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_date: Mapped[date] = mapped_column(Date, nullable=False)
    child_age: Mapped[str | None] = mapped_column(String(20), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    tags: Mapped[list["WorkTag"]] = relationship(
        back_populates="work", cascade="all, delete-orphan"
    )


class WorkTag(Base):
    """作品标签模型。"""

    __tablename__ = "work_tags"

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    work_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("works.id"), nullable=False, index=True
    )
    tag_name: Mapped[str] = mapped_column(String(50), nullable=False)
    is_ai_generated: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    work: Mapped["Work"] = relationship(back_populates="tags")
