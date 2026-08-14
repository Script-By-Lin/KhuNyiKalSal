-- =========================================================================
-- Railway PostgreSQL Migration Script for KhuNyiKalSal
-- Paste this script into Railway -> PostgreSQL -> Data / Query tab and execute.
-- =========================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create or Update 'sessions' Table for Multi-Device Session Management & Push Tokens
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

-- 3. Add fcm_token column if sessions table already existed without it
ALTER TABLE sessions 
ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500);

-- 4. Create Indexes on sessions table
CREATE INDEX IF NOT EXISTS ix_sessions_user_id ON sessions (user_id);
CREATE INDEX IF NOT EXISTS ix_sessions_device_id ON sessions (device_id);
CREATE INDEX IF NOT EXISTS ix_sessions_refresh_token_hash ON sessions (refresh_token_hash);
CREATE INDEX IF NOT EXISTS ix_sessions_fcm_token ON sessions (fcm_token);
CREATE INDEX IF NOT EXISTS ix_sessions_is_active ON sessions (is_active);

-- 5. Ensure emergencies table has assigned_volunteer_id for First-Responder Dispatch
ALTER TABLE emergencies 
ADD COLUMN IF NOT EXISTS assigned_volunteer_id UUID REFERENCES volunteers(account_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_emergencies_assigned_volunteer_id ON emergencies (assigned_volunteer_id);

-- 6. Update Alembic version table if alembic is used
CREATE TABLE IF NOT EXISTS alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Record latest migration stamp
DELETE FROM alembic_version;
INSERT INTO alembic_version (version_num) VALUES ('006_add_fcm_token');
