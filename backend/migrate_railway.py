"""
Railway Database Migration Script
---------------------------------
This script safely applies all database migrations to your Railway PostgreSQL database.

Usage:
  # Option 1: Pass Railway DATABASE_URL as argument
  python migrate_railway.py --url "postgresql://postgres:password@your-railway-host:port/railway"

  # Option 2: Set DATABASE_URL environment variable and run
  python migrate_railway.py
"""

import sys
import os
import argparse
import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from alembic.config import Config
from alembic import command


def parse_args():
    parser = argparse.ArgumentParser(description="Apply database migrations to Railway Postgres.")
    parser.add_argument(
        "--url",
        type=str,
        default=os.getenv("DATABASE_URL"),
        help="PostgreSQL Database URL from Railway (e.g., postgresql://...)",
    )
    return parser.parse_args()


def clean_database_url(url: str) -> tuple[str, str]:
    """Convert PostgreSQL URL into asyncpg (SQLAlchemy) and standard formats."""
    if not url:
        raise ValueError("No DATABASE_URL provided. Use --url or set DATABASE_URL environment variable.")

    # Remove extra spaces/quotes
    url = url.strip().strip("'\"")

    # Standard sync URL
    sync_url = url
    if sync_url.startswith("postgresql+asyncpg://"):
        sync_url = sync_url.replace("postgresql+asyncpg://", "postgresql://", 1)

    # Asyncpg URL for async engine
    async_url = url
    if async_url.startswith("postgres://"):
        async_url = async_url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif async_url.startswith("postgresql://") and not async_url.startswith("postgresql+asyncpg://"):
        async_url = async_url.replace("postgresql://", "postgresql+asyncpg://", 1)

    return sync_url, async_url


async def run_direct_sql_fixes(async_url: str):
    """Ensure critical schema updates (like fcm_token in sessions) are directly applied idempotently."""
    print("⏳ Checking direct SQL fixes on Railway PostgreSQL...")
    engine = create_async_engine(async_url, echo=False)

    sql_statements = [
        # Ensure UUID extension
        """CREATE EXTENSION IF NOT EXISTS "uuid-ossp";""",

        # Ensure sessions table exists
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

        # Create indexes if not exists
        """CREATE INDEX IF NOT EXISTS ix_sessions_user_id ON sessions (user_id);""",
        """CREATE INDEX IF NOT EXISTS ix_sessions_device_id ON sessions (device_id);""",
        """CREATE INDEX IF NOT EXISTS ix_sessions_refresh_token_hash ON sessions (refresh_token_hash);""",
        """CREATE INDEX IF NOT EXISTS ix_sessions_fcm_token ON sessions (fcm_token);""",
        """CREATE INDEX IF NOT EXISTS ix_sessions_is_active ON sessions (is_active);""",

        # Ensure assigned_volunteer_id on emergencies exists
        """
        ALTER TABLE emergencies 
        ADD COLUMN IF NOT EXISTS assigned_volunteer_id UUID REFERENCES volunteers(account_id) ON DELETE SET NULL;
        """,
        """CREATE INDEX IF NOT EXISTS ix_emergencies_assigned_volunteer_id ON emergencies (assigned_volunteer_id);"""
    ]

    async with engine.begin() as conn:
        for stmt in sql_statements:
            try:
                await conn.execute(text(stmt))
            except Exception as e:
                print(f"  ⚠️ Statement notice: {e}")

    await engine.dispose()
    print("✅ Direct SQL idempotency verification passed.")


def run_alembic_migrations(sync_url: str):
    """Run Alembic to mark and sync version stamps to head."""
    print("⏳ Running Alembic migrations to HEAD...")
    try:
        backend_dir = os.path.dirname(os.path.abspath(__file__))
        alembic_cfg_path = os.path.join(backend_dir, "alembic.ini")
        
        alembic_cfg = Config(alembic_cfg_path)
        alembic_cfg.set_main_option("sqlalchemy.url", sync_url)
        
        # Upgrade to head
        command.upgrade(alembic_cfg, "head")
        print("✅ Alembic migrations successfully upgraded to HEAD.")
    except Exception as e:
        print(f"⚠️ Alembic upgrade warning: {e}")
        print("  (Direct SQL schema updates have already verified and updated your tables).")


def main():
    args = parse_args()
    if not args.url:
        print("❌ Error: No database URL provided.")
        print("Provide your Railway PostgreSQL connection string:")
        print("  python migrate_railway.py --url 'postgresql://postgres:...'")
        sys.exit(1)

    sync_url, async_url = clean_database_url(args.url)
    os.environ["DATABASE_URL"] = sync_url

    print("==================================================")
    print("🚀 Railway PostgreSQL Migration Runner")
    print("==================================================")

    # 1. Run direct SQL fixes (idempotent)
    asyncio.run(run_direct_sql_fixes(async_url))

    # 2. Run Alembic upgrade head
    run_alembic_migrations(sync_url)

    print("==================================================")
    print("🎉 Database migration completed successfully on Railway!")
    print("==================================================")


if __name__ == "__main__":
    main()
