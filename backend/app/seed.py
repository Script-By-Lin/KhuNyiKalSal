"""
Database table initialization script — clean setup without dummy sample data.

Usage:
    cd backend
    python -m app.seed
"""

import asyncio
from sqlalchemy import select

from app.database import async_session_maker, create_tables
from app.models import Account, RoleEnum
from app.core.security import hash_password


async def seed(drop: bool = False):
    """Create all clean tables without dummy sample data."""
    await create_tables(drop=drop)

    async with async_session_maker() as db:
        # ── System Super Admin Account ────────────────────────────────────
        admin_email = "admin@khunyikalsal.com"
        admin_res = await db.execute(select(Account).where(Account.email == admin_email))
        if not admin_res.scalar_one_or_none():
            admin_acc = Account(
                email=admin_email,
                hashed_password=hash_password("admin123456"),
                role=RoleEnum.ADMIN,
            )
            db.add(admin_acc)
            await db.commit()

        print("[OK] Clean database schema created successfully!")
        print("    • All dummy sample data removed.")
        print("    • Super Admin: admin@khunyikalsal.com")


if __name__ == "__main__":
    asyncio.run(seed(drop=True))
