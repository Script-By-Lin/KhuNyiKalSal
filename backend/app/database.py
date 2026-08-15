"""Database connection and session configuration with PostgreSQL production pooling and self-healing schema."""

import logging
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base

from app.config import settings

logger = logging.getLogger(__name__)

Base = declarative_base()

# Production-grade async engine with connection pooling and health checks
engine_kwargs = {
    "echo": False,
    "future": True,
}

if not settings.async_database_url.startswith("sqlite"):
    engine_kwargs.update({
        "pool_size": 15,
        "max_overflow": 25,
        "pool_recycle": 300,
        "pool_pre_ping": True,
    })

engine = create_async_engine(settings.async_database_url, **engine_kwargs)

async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency for providing an async database session per request."""
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
            Announcement, SupportInfo,
        )
        if drop:
            try:
                await conn.run_sync(Base.metadata.drop_all)
            except Exception as e:
                logger.warning(f"Drop all tables note: {e}")

        # Safe metadata table creation
        try:
            await conn.run_sync(Base.metadata.create_all)
        except Exception as e:
            logger.warning(f"Metadata create_all notice (safe concurrent handling): {e}")

        # Self-healing column, table, and index additions for live production databases
        try:
            from sqlalchemy import text
            if not settings.async_database_url.startswith("sqlite"):
                # 1. Announcements self-healing table & columns
                await conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS announcements (
                        id UUID PRIMARY KEY,
                        title VARCHAR(255) NOT NULL,
                        content TEXT NOT NULL,
                        category VARCHAR(50) DEFAULT 'General',
                        author_name VARCHAR(100) DEFAULT 'Emergency Command Center',
                        is_pinned BOOLEAN DEFAULT FALSE,
                        is_active BOOLEAN DEFAULT TRUE,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                    );
                """))
                await conn.execute(text("ALTER TABLE announcements ADD COLUMN IF NOT EXISTS content TEXT;"))
                await conn.execute(text("ALTER TABLE announcements ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'General';"))
                await conn.execute(text("ALTER TABLE announcements ADD COLUMN IF NOT EXISTS author_name VARCHAR(100) DEFAULT 'Emergency Command Center';"))
                await conn.execute(text("ALTER TABLE announcements ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;"))
                await conn.execute(text("ALTER TABLE announcements ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;"))
                await conn.execute(text("ALTER TABLE announcements ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;"))
                await conn.execute(text("ALTER TABLE announcements ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;"))

                # 2. Support Info self-healing table & columns
                await conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS support_info (
                        id UUID PRIMARY KEY,
                        kbz_pay_name VARCHAR(100) DEFAULT 'Khu Nyi Kal Sal Relief Fund',
                        kbz_pay_phone VARCHAR(50) DEFAULT '09789123456',
                        wave_pay_name VARCHAR(100) DEFAULT 'Khu Nyi Kal Sal Relief Fund',
                        wave_pay_phone VARCHAR(50) DEFAULT '09789123456',
                        bank_name VARCHAR(100) DEFAULT 'KBZ Bank',
                        bank_account_number VARCHAR(100) DEFAULT '123-456-789012345',
                        bank_account_name VARCHAR(100) DEFAULT 'Khu Nyi Kal Sal Emergency Response',
                        mmqr_payload TEXT,
                        note_message TEXT,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                    );
                """))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS kbz_pay_name VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS kbz_pay_phone VARCHAR(50);"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS wave_pay_name VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS wave_pay_phone VARCHAR(50);"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS bank_account_name VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS mmqr_payload TEXT;"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS note_message TEXT;"))
                await conn.execute(text("ALTER TABLE support_info ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;"))

                # 3. Sessions FCM token self-healing
                await conn.execute(text("ALTER TABLE sessions ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_sessions_fcm_token ON sessions (fcm_token);"))
                
                # 4. Organizations created_at & fields self-healing
                await conn.execute(text("ALTER TABLE organizations ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;"))
                await conn.execute(text("ALTER TABLE organizations ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'Medical';"))
                await conn.execute(text("ALTER TABLE organizations ADD COLUMN IF NOT EXISTS headquarters_address VARCHAR(500);"))
                await conn.execute(text("ALTER TABLE organizations ADD COLUMN IF NOT EXISTS operating_regions VARCHAR(255);"))
                await conn.execute(text("ALTER TABLE organizations ADD COLUMN IF NOT EXISTS registration_number VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE organizations ADD COLUMN IF NOT EXISTS coverage_radius_km FLOAT DEFAULT 50.0;"))
                
                # 5. Blood Donations columns self-healing
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS request_type VARCHAR(20) DEFAULT 'donate';"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS patient_name VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS hospital_name VARCHAR(200);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS urgency_level VARCHAR(50);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS accepted_org_id UUID REFERENCES accounts(id) ON DELETE SET NULL;"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS pickup_location_message TEXT;"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_date VARCHAR(100);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_location VARCHAR(200);"))
                await conn.execute(text("ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_notes TEXT;"))
                
                # 6. Performance Composite Indexes
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_blood_req_status ON blood_donations (request_type, status);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_blood_accepted_org ON blood_donations (accepted_org_id);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_blood_type ON blood_donations (blood_type);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_emergency_type_status ON emergencies (type, status);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_emergency_assigned_org ON emergencies (assigned_org_id);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_emergency_user_created ON emergencies (user_id, created_at);"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_announcements_pinned_created ON announcements (is_pinned, created_at);"))
        except Exception as e:
            logger.warning(f"Production schema self-healing check note: {e}")
