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
    from app.models import (  # noqa: F401
        Account, UserProfile, Organization, Volunteer, Emergency,
        FamilyGroup, FamilyMember, FamilyAlert, UserSession, BloodDonation,
        Announcement, SupportInfo,
    )

    # 1. Base Metadata table creation in isolated connection
    async with engine.begin() as conn:
        if drop:
            try:
                await conn.run_sync(Base.metadata.drop_all)
            except Exception as e:
                logger.warning(f"Drop all tables note: {e}")

        try:
            await conn.run_sync(Base.metadata.create_all)
        except Exception as e:
            logger.warning(f"Metadata create_all notice (safe concurrent handling): {e}")

    # 2. Self-healing column, enum, and index additions for live production databases
    # Each DDL statement runs in its own AUTOCOMMIT connection to prevent transaction abort cascades
    if not settings.async_database_url.startswith("sqlite"):
        from sqlalchemy import text
        ddl_statements = [
            # 1. Announcements table & columns
            """
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
            """,
            "ALTER TABLE announcements ADD COLUMN IF NOT EXISTS content TEXT;",
            "ALTER TABLE announcements ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'General';",
            "ALTER TABLE announcements ADD COLUMN IF NOT EXISTS author_name VARCHAR(100) DEFAULT 'Emergency Command Center';",
            "ALTER TABLE announcements ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;",
            "ALTER TABLE announcements ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;",
            "ALTER TABLE announcements ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;",
            "ALTER TABLE announcements ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;",

            # 2. Support Info table & columns
            """
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
            """,
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS kbz_pay_name VARCHAR(100);",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS kbz_pay_phone VARCHAR(50);",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS wave_pay_name VARCHAR(100);",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS wave_pay_phone VARCHAR(50);",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100);",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(100);",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS bank_account_name VARCHAR(100);",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS mmqr_payload TEXT;",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS mmqr_image_url TEXT;",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS note_message TEXT;",
            "ALTER TABLE support_info ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;",

            # 3. Sessions FCM token
            "ALTER TABLE sessions ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500);",
            "CREATE INDEX IF NOT EXISTS ix_sessions_fcm_token ON sessions (fcm_token);",

            # 4. Organizations fields
            "ALTER TABLE organizations ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;",
            "ALTER TABLE organizations ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'Medical';",
            "ALTER TABLE organizations ADD COLUMN IF NOT EXISTS headquarters_address VARCHAR(500);",
            "ALTER TABLE organizations ADD COLUMN IF NOT EXISTS operating_regions VARCHAR(255);",
            "ALTER TABLE organizations ADD COLUMN IF NOT EXISTS registration_number VARCHAR(100);",
            "ALTER TABLE organizations ADD COLUMN IF NOT EXISTS coverage_radius_km FLOAT DEFAULT 50.0;",

            # 5. Blood Donations columns
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS request_type VARCHAR(20) DEFAULT 'donate';",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS patient_name VARCHAR(100);",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS hospital_name VARCHAR(200);",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS urgency_level VARCHAR(50);",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS accepted_org_id UUID REFERENCES accounts(id) ON DELETE SET NULL;",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS pickup_location_message TEXT;",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_date VARCHAR(100);",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_location VARCHAR(200);",
            "ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS appointment_notes TEXT;",

            # 6. Family Member status (pending/accepted/denied)
            "ALTER TABLE family_members ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'accepted';",
            "CREATE INDEX IF NOT EXISTS ix_family_members_status ON family_members (status);",

            # 7. Password Reset OTP Table
            """CREATE TABLE IF NOT EXISTS password_reset_otps (
                id UUID PRIMARY KEY,
                email VARCHAR(255) NOT NULL,
                otp_code VARCHAR(6) NOT NULL,
                expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
                is_used BOOLEAN NOT NULL DEFAULT FALSE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );""",
            "CREATE INDEX IF NOT EXISTS ix_password_reset_otps_email ON password_reset_otps (email);",

            # 8. Ensure column types are standard VARCHAR(50) to prevent enum type mismatch
            "ALTER TABLE emergencies ALTER COLUMN type TYPE VARCHAR(50) USING type::text;",
            "ALTER TABLE emergencies ALTER COLUMN status TYPE VARCHAR(50) USING status::text;",
            "ALTER TABLE accounts ALTER COLUMN role TYPE VARCHAR(50) USING role::text;",

            # 8.1 Progressive 3-Tier Suspension Tracking on accounts
            "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;",
            "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMP WITH TIME ZONE;",
            "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS suspension_count INTEGER DEFAULT 0;",
            "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS suspension_reason VARCHAR(500);",
            "CREATE INDEX IF NOT EXISTS ix_accounts_suspended ON accounts (is_suspended, suspended_until);",

            # 9. Normalize case values
            "UPDATE emergencies SET type = lower(type) WHERE type IS NOT NULL AND type != lower(type);",
            "UPDATE emergencies SET status = lower(status) WHERE status IS NOT NULL AND status != lower(status);",
            "UPDATE accounts SET role = upper(role) WHERE role IS NOT NULL AND role != upper(role);",

            # 10. Performance Indexes
            "CREATE INDEX IF NOT EXISTS ix_blood_req_status ON blood_donations (request_type, status);",
            "CREATE INDEX IF NOT EXISTS ix_blood_accepted_org ON blood_donations (accepted_org_id);",
            "CREATE INDEX IF NOT EXISTS ix_blood_type ON blood_donations (blood_type);",
            "CREATE INDEX IF NOT EXISTS ix_emergency_type_status ON emergencies (type, status);",
            "CREATE INDEX IF NOT EXISTS ix_emergency_assigned_org ON emergencies (assigned_org_id);",
            "CREATE INDEX IF NOT EXISTS ix_emergency_user_created ON emergencies (user_id, created_at);",
            "CREATE INDEX IF NOT EXISTS ix_announcements_pinned_created ON announcements (is_pinned, created_at);",
        ]

        for stmt in ddl_statements:
            stmt = stmt.strip()
            if not stmt:
                continue
            try:
                async with engine.connect() as conn:
                    conn = await conn.execution_options(isolation_level="AUTOCOMMIT")
                    await conn.execute(text(stmt))
            except Exception as e:
                logger.debug(f"Self-healing DDL note ({stmt[:50]}...): {e}")
