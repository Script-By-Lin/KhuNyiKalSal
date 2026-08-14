from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

engine_kwargs = {"echo": False}
if not settings.async_database_url.startswith("sqlite"):
    engine_kwargs.update({"pool_size": 20, "max_overflow": 50})

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
