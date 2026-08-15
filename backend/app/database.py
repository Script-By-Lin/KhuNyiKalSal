import os
import logging
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

logger = logging.getLogger(__name__)

engine_kwargs = {"echo": False}
if not settings.async_database_url.startswith("sqlite"):
    pool_size = int(os.environ.get("DB_POOL_SIZE", "15"))
    max_overflow = int(os.environ.get("DB_MAX_OVERFLOW", "25"))
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
    """Create all tables on startup. Import all models so metadata is populated."""
    async with engine.begin() as conn:
        from app.models import (  # noqa: F401
            Account, UserProfile, Organization, Volunteer, Emergency,
            FamilyGroup, FamilyMember, FamilyAlert, UserSession, BloodDonation,
        )
        if drop:
            await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

        # Self-healing column & table additions for live production databases
        try:
            from sqlalchemy import text
            if not settings.async_database_url.startswith("sqlite"):
                # Sessions FCM token self-healing
                await conn.execute(text("ALTER TABLE sessions ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_sessions_fcm_token ON sessions (fcm_token);"))
                
                # Blood Donations columns self-healing
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS request_type VARCHAR(20) DEFAULT 'donate';"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS patient_name VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS hospital_name VARCHAR(200);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS urgency_level VARCHAR(50);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS accepted_org_id UUID REFERENCES accounts(id) ON DELETE SET NULL;"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS pickup_location_message TEXT;"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_date VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_location VARCHAR(200);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_notes TEXT;"))
                
                # Performance Indexes
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_blood_req_status ON blood_donations (request_type, status);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_blood_accepted_org ON blood_donations (accepted_org_id);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_blood_type ON blood_donations (blood_type);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_emergency_type_status ON emergencies (type, status);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_emergency_assigned_org ON emergencies (assigned_org_id);"))
        except Exception as e:
            logger.warning(f"Production schema self-healing check note: {e}")
