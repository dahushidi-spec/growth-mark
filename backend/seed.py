"""种子数据脚本：创建测试用户、家庭、孩子、作品与荣誉。

运行方式：python seed.py
"""

import asyncio
import secrets
from datetime import date, timedelta

from sqlalchemy import select

from app.core.database import async_session_factory, engine
from app.core.security import hash_password
from app.models.family import Family, FamilyMember, FamilyRole
from app.models.honor import Honor, HonorLevel
from app.models.user import Child, User
from app.models.work import Work, WorkCategory

PHONE = "13800138000"
PASSWORD = "123456"


async def seed() -> None:
    # 建表（开发环境快捷方式；生产环境请使用 alembic 迁移）
    async with engine.begin() as conn:
        await conn.run_sync(lambda c: None)  # 确保引擎可用

    async with async_session_factory() as db:
        # 创建测试用户
        result = await db.execute(select(User).where(User.phone == PHONE))
        user = result.scalar_one_or_none()
        if user is None:
            user = User(
                phone=PHONE,
                password_hash=hash_password(PASSWORD),
                nickname="测试家长",
            )
            db.add(user)
            await db.flush()
        else:
            print(f"用户已存在: {user.phone}")

        # 创建 2 个孩子
        result = await db.execute(select(Child).where(Child.user_id == user.id))
        children = result.scalars().all()
        if len(children) < 2:
            children = [
                Child(
                    user_id=user.id,
                    name="小明",
                    gender=1,
                    birth_date=date(2016, 5, 10),
                    avatar_url=None,
                ),
                Child(
                    user_id=user.id,
                    name="小红",
                    gender=0,
                    birth_date=date(2018, 9, 1),
                    avatar_url=None,
                ),
            ]
            db.add_all(children)
            await db.flush()

        # 创建 1 个家庭（Demo 用）
        result = await db.execute(select(Family).where(Family.creator_id == user.id))
        family = result.scalar_one_or_none()
        if family is None:
            invite_code = secrets.token_hex(3).upper()[:6]  # 6 位邀请码
            family = Family(
                name="成长之家",
                invite_code=invite_code,
                creator_id=user.id,
            )
            db.add(family)
            await db.flush()
            # 创建者自动成为家庭成员
            member = FamilyMember(
                family_id=family.id,
                user_id=user.id,
                role=FamilyRole.creator,
            )
            db.add(member)
            await db.flush()

        today = date.today()
        categories = list(WorkCategory)
        levels = list(HonorLevel)
        orgs = ["少年宫", "教育局", "美术协会", "学校", "少年宫"]

        # 创建 20 条作品
        existing_works = (
            await db.execute(select(Work).where(Work.user_id == user.id))
        ).scalars().all()
        if len(existing_works) < 20:
            for i in range(20):
                child = children[i % len(children)]
                # 6 张占位图循环使用
                img = f"/uploads/demo/works_{i % 6}.svg"
                work = Work(
                    child_id=child.id,
                    user_id=user.id,
                    title=f"作品第{i + 1}号",
                    category=categories[i % len(categories)],
                    description=f"这是第 {i + 1} 件作品的描述。",
                    image_url=img,
                    thumbnail_url=img,
                    created_date=today - timedelta(days=i * 3),
                    child_age=f"{6 + i % 3}岁",
                )
                db.add(work)
            await db.flush()

        # 创建 10 条荣誉
        existing_honors = (
            await db.execute(select(Honor).where(Honor.user_id == user.id))
        ).scalars().all()
        if len(existing_honors) < 10:
            for i in range(10):
                child = children[i % len(children)]
                img = f"/uploads/demo/honors_{i % 4}.svg"
                honor = Honor(
                    child_id=child.id,
                    user_id=user.id,
                    title=f"荣誉第{i + 1}号",
                    level=levels[i % len(levels)],
                    category=["绘画", "书法", "手工", "音乐"][i % 4],
                    image_url=img,
                    award_date=today - timedelta(days=i * 15),
                    organization=orgs[i % len(orgs)],
                    description=f"这是第 {i + 1} 项荣誉的描述。",
                )
                db.add(honor)

        await db.commit()

    await engine.dispose()
    print("种子数据创建完成:")
    print(f"  用户: {PHONE} / {PASSWORD}")
    print(f"  家庭: 成长之家 (邀请码: {family.invite_code})")
    print("  孩子: 2 名（小明、小红）")
    print("  作品: 20 条")
    print("  荣誉: 10 条")


if __name__ == "__main__":
    asyncio.run(seed())
