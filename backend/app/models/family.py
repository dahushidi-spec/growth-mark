"""家庭与家庭成员模型。"""

import enum
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class FamilyRole(str, enum.Enum):
    """家庭成员角色。"""

    creator = "creator"
    admin = "admin"
    member = "member"


class Family(Base):
    """家庭模型。"""

    __tablename__ = "families"

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    invite_code: Mapped[str] = mapped_column(
        String(6), unique=True, index=True, nullable=False
    )
    creator_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    members: Mapped[list["FamilyMember"]] = relationship(
        back_populates="family", cascade="all, delete-orphan"
    )


class FamilyMember(Base):
    """家庭成员模型。"""

    __tablename__ = "family_members"
    __table_args__ = (UniqueConstraint("family_id", "user_id", name="uq_family_user"),)

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    family_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("families.id"), nullable=False, index=True
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False, index=True
    )
    role: Mapped[FamilyRole] = mapped_column(
        Enum(FamilyRole), default=FamilyRole.member, nullable=False
    )
    joined_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    family: Mapped["Family"] = relationship(back_populates="members")
