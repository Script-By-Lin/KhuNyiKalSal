import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

engine_kwargs = {"echo": False}
if not settings.async_database_url.startswith("sqlite"):
    pool_size = int(os.environ.get("DB_POOL_SIZE", "5"))
    max_overflow = int(os.environ.get("DB_MAX_OVERFLOW", "5"))
    engine_kwargs.update({
        "pool_size": pool_size,
        "max_overflow": max_overflow,
        "pool_recycle": 300,
        "pool_pre_ping": True,
        "pool_timeout": 30,
    })

engine = create_async_engine(
    settings.async_database_url, 
    **engine_kwargs,
)
async_session_maker = async_sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""
    pass


async def get_db():
    """FastAPI dependency that yields an async DB session."""
    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()


async def create_tables(drop: bool = False):
    """Create all tables on startup. Import models so metadata is populated."""
    async with engine.begin() as conn:
        from app.models import (  # noqa: F401
            Account, UserProfile, Organization, Volunteer, Emergency,
            FamilyGroup, FamilyMember, FamilyAlert, UserSession,
        )
        if drop:
            await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

        # Self-healing column additions for existing production databases (e.g. Railway)
        try:
            from sqlalchemy import text
            if not settings.async_database_url.startswith("sqlite"):
                await conn.execute(text("ALTER TABLE sessions ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_sessions_fcm_token ON sessions (fcm_token);"))
        except Exception:
            pass
