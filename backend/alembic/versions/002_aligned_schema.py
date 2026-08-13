"""Initial database schema migration — fully aligned with ORM models

Revision ID: 002_aligned_schema
Revises: 001_initial_schema
Create Date: 2026-08-13 23:25:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '002_aligned_schema'
down_revision: Union[str, None] = '001_initial_schema'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Drop all existing tables in reverse dependency order ──────────────
    op.drop_table('family_alerts')
    op.drop_table('family_members')
    op.drop_table('family_groups')
    op.drop_table('emergencies')
    op.drop_table('volunteers')
    op.drop_table('organizations')
    op.drop_table('user_profiles')
    op.drop_table('accounts')

    # Drop old enum types if they exist
    op.execute("DROP TYPE IF EXISTS roleenum CASCADE")
    op.execute("DROP TYPE IF EXISTS emergencytype CASCADE")
    op.execute("DROP TYPE IF EXISTS emergencystatus CASCADE")

    # ── Create PostgreSQL enum types ──────────────────────────────────────
    op.execute("CREATE TYPE roleenum AS ENUM ('USER', 'ORGANIZATION', 'VOLUNTEER', 'ADMIN')")
    op.execute("CREATE TYPE emergency_type_enum AS ENUM ('fire', 'medical', 'crime')")
    op.execute("CREATE TYPE emergency_status_enum AS ENUM ('pending', 'accepted', 'completed', 'cancelled')")

    # ── 1. Accounts ───────────────────────────────────────────────────────
    op.create_table(
        'accounts',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('hashed_password', sa.String(length=255), nullable=False),
        sa.Column('role', sa.Enum('USER', 'ORGANIZATION', 'VOLUNTEER', 'ADMIN', name='roleenum', create_type=False), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('email')
    )
    op.create_index('ix_accounts_email', 'accounts', ['email'])

    # ── 2. User Profiles ──────────────────────────────────────────────────
    op.create_table(
        'user_profiles',
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('phone_number', sa.String(length=500), nullable=False),
        sa.Column('phone_salt', sa.String(length=64), nullable=True),
        sa.Column('blood_type', sa.String(length=10), nullable=True),
        sa.Column('medical_conditions', sa.Text(), nullable=True),
        sa.Column('emergency_contacts', sa.JSON(), nullable=True),
        sa.Column('location_lat', sa.Float(), nullable=True),
        sa.Column('location_lng', sa.Float(), nullable=True),
        sa.Column('location_salt', sa.String(length=64), nullable=True),
        sa.Column('family_id', sa.String(length=100), nullable=True),
        sa.Column('nrc_number', sa.String(length=100), nullable=True),
        sa.Column('date_of_birth', sa.Date(), nullable=True),
        sa.Column('gender', sa.String(length=20), nullable=True),
        sa.Column('medical_profile', sa.JSON(), nullable=True),
        sa.Column('address_info', sa.JSON(), nullable=True),
        sa.Column('last_synced_at', sa.Date(), nullable=True),
        sa.Column('is_blocked', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('sos_count_today', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('last_sos_date', sa.Date(), nullable=True),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('account_id')
    )

    # ── 3. Organizations ──────────────────────────────────────────────────
    op.create_table(
        'organizations',
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('org_name', sa.String(length=255), nullable=False),
        sa.Column('phone_number', sa.String(length=500), nullable=False),
        sa.Column('phone_salt', sa.String(length=64), nullable=True),
        sa.Column('geo_lat', sa.Float(), nullable=False),
        sa.Column('geo_lng', sa.Float(), nullable=False),
        sa.Column('registration_number', sa.String(length=100), nullable=True),
        sa.Column('headquarters_address', sa.String(length=255), nullable=True),
        sa.Column('operating_regions', sa.String(length=255), nullable=True),
        sa.Column('category', sa.String(length=50), nullable=True, server_default="'Medical'"),
        sa.Column('status', sa.String(length=50), nullable=True, server_default="'Active'"),
        sa.Column('coverage_radius_km', sa.Float(), nullable=True, server_default='50.0'),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('account_id')
    )

    # ── 4. Volunteers ─────────────────────────────────────────────────────
    op.create_table(
        'volunteers',
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('org_id', sa.UUID(), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('phone_number', sa.String(length=500), nullable=False),
        sa.Column('phone_salt', sa.String(length=64), nullable=True),
        sa.Column('nrc_number', sa.String(length=100), nullable=True),
        sa.Column('date_of_birth', sa.String(length=50), nullable=True),
        sa.Column('emergency_contact', sa.String(length=50), nullable=True),
        sa.Column('assigned_region', sa.String(length=100), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('current_lat', sa.Float(), nullable=True),
        sa.Column('current_lng', sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['org_id'], ['organizations.account_id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('account_id')
    )

    # ── 5. Emergencies ────────────────────────────────────────────────────
    op.create_table(
        'emergencies',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('type', sa.Enum('fire', 'medical', 'crime', name='emergency_type_enum', create_type=False), nullable=False),
        sa.Column('status', sa.Enum('pending', 'accepted', 'completed', 'cancelled', name='emergency_status_enum', create_type=False), nullable=True),
        sa.Column('assigned_org_id', sa.UUID(), nullable=True),
        sa.Column('assigned_volunteer_id', sa.UUID(), nullable=True),
        sa.Column('location_lat', sa.Float(), nullable=False),
        sa.Column('location_lng', sa.Float(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['assigned_org_id'], ['organizations.account_id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['assigned_volunteer_id'], ['volunteers.account_id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )

    # ── 6. Family Groups ─────────────────────────────────────────────────
    op.create_table(
        'family_groups',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('group_name', sa.String(length=255), nullable=False),
        sa.Column('creator_id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['creator_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # ── 7. Family Members ─────────────────────────────────────────────────
    op.create_table(
        'family_members',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('family_id', sa.UUID(), nullable=False),
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('relationship', sa.String(length=50), nullable=False),
        sa.Column('added_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['family_id'], ['family_groups.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # ── 8. Family Alerts ──────────────────────────────────────────────────
    op.create_table(
        'family_alerts',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('family_id', sa.UUID(), nullable=False),
        sa.Column('sender_id', sa.UUID(), nullable=False),
        sa.Column('emergency_id', sa.UUID(), nullable=True),
        sa.Column('emergency_type', sa.String(length=50), nullable=False),
        sa.Column('location_lat', sa.Float(), nullable=False),
        sa.Column('location_lng', sa.Float(), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['emergency_id'], ['emergencies.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['family_id'], ['family_groups.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['sender_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('family_alerts')
    op.drop_table('family_members')
    op.drop_table('family_groups')
    op.drop_table('emergencies')
    op.drop_table('volunteers')
    op.drop_table('organizations')
    op.drop_table('user_profiles')
    op.drop_table('accounts')
    op.execute("DROP TYPE IF EXISTS roleenum CASCADE")
    op.execute("DROP TYPE IF EXISTS emergency_type_enum CASCADE")
    op.execute("DROP TYPE IF EXISTS emergency_status_enum CASCADE")
