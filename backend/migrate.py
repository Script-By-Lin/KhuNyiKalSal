"""
Database Migration & Auto-Schema Sync Runner for Railway / Docker
-----------------------------------------------------------------
Executes every time the backend container starts (e.g. after git push to GitHub).
1. Ensures critical schema tables and columns exist idempotently via direct SQL.
2. Runs 'alembic upgrade head' to apply any pending Alembic revisions.
"""

import os
import sys
import subprocess
import asyncio
import concurrent.futures
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from app.config import settings


async def ensure_idempotent_schema():
    """Apply critical DDL statements directly to ensure schema completeness."""
    db_url = settings.async_database_url
    if not db_url or "sqlite" in db_url:
        return

    print("⏳ Auto-Syncing PostgreSQL schema on Railway...")
    try:
        engine = create_async_engine(db_url, echo=False)
        sql_statements = [
            # Ensure UUID extension
            """CREATE EXTENSION IF NOT EXISTS "uuid-ossp";""",

            # Ensure sessions table exists for device and push token management
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                user_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                device_id VARCHAR(255),
                device_name VARCHAR(255),
                refresh_token_hash VARCHAR(255) NOT NULL,
                ip_address VARCHAR(100),
                user_agent VARCHAR(500),
                fcm_token VARCHAR(500),
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            """,

            # Add fcm_token if sessions table already existed without it
            """
            ALTER TABLE sessions 
            ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500);
            """,

            # Indexes for sessions table
            """CREATE INDEX IF NOT EXISTS ix_sessions_user_id ON sessions (user_id);""",
            """CREATE INDEX IF NOT EXISTS ix_sessions_device_id ON sessions (device_id);""",
            """CREATE INDEX IF NOT EXISTS ix_sessions_refresh_token_hash ON sessions (refresh_token_hash);""",
            """CREATE INDEX IF NOT EXISTS ix_sessions_fcm_token ON sessions (fcm_token);""",
            """CREATE INDEX IF NOT EXISTS ix_sessions_is_active ON sessions (is_active);""",

            # Ensure assigned_volunteer_id for First-Responder SOS dispatch
            """
            ALTER TABLE emergencies 
            ADD COLUMN IF NOT EXISTS assigned_volunteer_id UUID REFERENCES volunteers(account_id) ON DELETE SET NULL;
            """,
            """CREATE INDEX IF NOT EXISTS ix_emergencies_assigned_volunteer_id ON emergencies (assigned_volunteer_id);""",

            # Ensure column types are standard VARCHAR(50) to prevent enum type mismatch
            """ALTER TABLE emergencies ALTER COLUMN type TYPE VARCHAR(50) USING type::text;""",
            """ALTER TABLE emergencies ALTER COLUMN status TYPE VARCHAR(50) USING status::text;""",
            """ALTER TABLE accounts ALTER COLUMN role TYPE VARCHAR(50) USING role::text;""",
            """UPDATE emergencies SET type = lower(type) WHERE type IS NOT NULL AND type != lower(type);""",
            """UPDATE emergencies SET status = lower(status) WHERE status IS NOT NULL AND status != lower(status);""",
            """UPDATE accounts SET role = upper(role) WHERE role IS NOT NULL AND role != upper(role);""",

            # Ensure blood_donations table exists
            """
            CREATE TABLE IF NOT EXISTS blood_donations (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                user_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                request_type VARCHAR(20) DEFAULT 'donate',
                patient_name VARCHAR(255),
                hospital_name VARCHAR(255),
                urgency_level VARCHAR(50) DEFAULT 'Normal',
                donor_name VARCHAR(255) NOT NULL,
                donor_phone VARCHAR(500) NOT NULL,
                donor_phone_salt VARCHAR(64),
                blood_type VARCHAR(10) NOT NULL,
                age INTEGER,
                gender VARCHAR(20),
                medical_notes VARCHAR(500),
                target_org_id UUID REFERENCES organizations(account_id) ON DELETE SET NULL,
                accepted_org_id UUID REFERENCES organizations(account_id) ON DELETE SET NULL,
                target_location_name VARCHAR(255) NOT NULL,
                target_lat DOUBLE PRECISION,
                target_lng DOUBLE PRECISION,
                preferred_date VARCHAR(100),
                units INTEGER DEFAULT 1,
                status VARCHAR(50) DEFAULT 'Pending',
                appointment_date VARCHAR(100),
                appointment_location VARCHAR(255),
                appointment_notes VARCHAR(500),
                pickup_location_message VARCHAR(500),
                notes VARCHAR(500),
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ
            );
            """,
            """ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS request_type VARCHAR(20) DEFAULT 'donate';""",
            """ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS patient_name VARCHAR(255);""",
            """ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS hospital_name VARCHAR(255);""",
            """ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS urgency_level VARCHAR(50) DEFAULT 'Normal';""",
            """ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS accepted_org_id UUID REFERENCES organizations(account_id) ON DELETE SET NULL;""",
            """ALTER TABLE blood_donations ADD COLUMN IF NOT EXISTS pickup_location_message VARCHAR(500);""",
            """CREATE INDEX IF NOT EXISTS ix_blood_donations_user_id ON blood_donations (user_id);""",
            """CREATE INDEX IF NOT EXISTS ix_blood_donations_target_org_id ON blood_donations (target_org_id);""",
            """CREATE INDEX IF NOT EXISTS ix_blood_donations_accepted_org_id ON blood_donations (accepted_org_id);""",
            """CREATE INDEX IF NOT EXISTS ix_blood_donations_request_type ON blood_donations (request_type);""",
            """CREATE INDEX IF NOT EXISTS ix_blood_donations_blood_type ON blood_donations (blood_type);""",
            """CREATE INDEX IF NOT EXISTS ix_blood_donations_status ON blood_donations (status);""",
            """ALTER TABLE family_members ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'accepted';""",
            """CREATE INDEX IF NOT EXISTS ix_family_members_status ON family_members (status);""",
            """CREATE TABLE IF NOT EXISTS password_reset_otps (
                id UUID PRIMARY KEY,
                email VARCHAR(255) NOT NULL,
                otp_code VARCHAR(6) NOT NULL,
                expires_at TIMESTAMPTZ NOT NULL,
                is_used BOOLEAN NOT NULL DEFAULT FALSE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );""",
            """CREATE INDEX IF NOT EXISTS ix_password_reset_otps_email ON password_reset_otps (email);"""
        ]

        for stmt in sql_statements:
            stmt = stmt.strip()
            if not stmt:
                continue
            try:
                async with engine.connect() as conn:
                    conn = await conn.execution_options(isolation_level="AUTOCOMMIT")
                    await conn.execute(text(stmt))
            except Exception as e:
                print(f"  [Notice] Schema check ({stmt[:40]}...): {e}")

        await engine.dispose()
        print("✅ Direct PostgreSQL schema verification completed.")
    except Exception as e:
        print(f"⚠️ Direct schema verification notice: {e}")


def run_alembic_upgrade():
    """Run alembic upgrade head using subprocess."""
    print("⏳ Executing Alembic migrations...")
    env = os.environ.copy()
    
    # Run alembic upgrade head
    res = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        capture_output=True,
        text=True,
        env=env,
    )

    if res.returncode == 0:
        print("✅ Alembic database migrations applied successfully!")
        if res.stdout.strip():
            print(res.stdout.strip())
    else:
        # If tables already exist before alembic versioning, stamp head
        if "already exists" in res.stderr:
            print("Database tables exist — stamping Alembic version to head...")
            stamp_res = subprocess.run(
                [sys.executable, "-m", "alembic", "stamp", "head"],
                capture_output=True,
                text=True,
                env=env,
            )
            if stamp_res.returncode == 0:
                print("✅ Alembic database stamped to head revision successfully!")
            else:
                print(f"Stamp notice: {stamp_res.stderr}")
        else:
            print(f"Alembic Migration Output: {res.stderr or res.stdout}")


def _run_async_safely(coro_fn):
    """Execute an async coroutine safely, even when an asyncio event loop is already running."""
    try:
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop is not None and loop.is_running():
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(lambda: asyncio.run(coro_fn()))
                return future.result()
        else:
            return asyncio.run(coro_fn())
    except Exception as e:
        print(f"⚠️ Async execution notice: {e}")


def run_migrations():
    """Entry point for running all migrations during startup."""
    try:
        _run_async_safely(ensure_idempotent_schema)
    except Exception as e:
        print(f"⚠️ ensure_idempotent_schema error: {e}")

    try:
        run_alembic_upgrade()
    except Exception as e:
        print(f"⚠️ run_alembic_upgrade error: {e}")


if __name__ == "__main__":
    run_migrations()
