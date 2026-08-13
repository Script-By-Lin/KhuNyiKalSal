"""Initial database schema migration with salted privacy and family system

Revision ID: 001_initial_schema
Revises: 
Create Date: 2026-08-13 22:48:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '001_initial_schema'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Accounts
    op.create_table(
        'accounts',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('hashed_password', sa.String(length=255), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('email')
    )

    # 2. User Profiles
    op.create_table(
        'user_profiles',
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('phone_number', sa.String(length=255), nullable=False),
        sa.Column('phone_salt', sa.String(length=255), nullable=True),
        sa.Column('blood_type', sa.String(length=10), nullable=True),
        sa.Column('medical_conditions', sa.Text(), nullable=True),
        sa.Column('nrc_number', sa.String(length=100), nullable=True),
        sa.Column('gender', sa.String(length=20), nullable=True),
        sa.Column('family_id', sa.String(length=100), nullable=True),
        sa.Column('medical_profile', sa.JSON(), nullable=True),
        sa.Column('address_info', sa.JSON(), nullable=True),
        sa.Column('emergency_contacts', sa.JSON(), nullable=True),
        sa.Column('base_location_lat', sa.Float(), nullable=True),
        sa.Column('base_location_lng', sa.Float(), nullable=True),
        sa.Column('location_salt', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('account_id')
    )

    # 3. Organizations
    op.create_table(
        'organizations',
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('org_name', sa.String(length=255), nullable=False),
        sa.Column('phone_number', sa.String(length=255), nullable=False),
        sa.Column('phone_salt', sa.String(length=255), nullable=True),
        sa.Column('geo_lat', sa.Float(), nullable=False),
        sa.Column('geo_lng', sa.Float(), nullable=False),
        sa.Column('registration_number', sa.String(length=100), nullable=True),
        sa.Column('headquarters_address', sa.Text(), nullable=True),
        sa.Column('operating_regions', sa.Text(), nullable=True),
        sa.Column('category', sa.String(length=50), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('coverage_radius_km', sa.Float(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),

        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('account_id')
    )

    # 4. Volunteers
    op.create_table(
        'volunteers',
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('org_id', sa.UUID(), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('phone_number', sa.String(length=255), nullable=False),
        sa.Column('phone_salt', sa.String(length=255), nullable=True),
        sa.Column('nrc_number', sa.String(length=100), nullable=False),
        sa.Column('date_of_birth', sa.String(length=20), nullable=True),
        sa.Column('emergency_contact', sa.String(length=255), nullable=True),
        sa.Column('assigned_region', sa.String(length=100), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('current_lat', sa.Float(), nullable=True),
        sa.Column('current_lng', sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['org_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('account_id')
    )

    # 5. Emergencies
    op.create_table(
        'emergencies',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('type', sa.Enum('FIRE', 'MEDICAL', 'CRIME', name='emergencytype'), nullable=False),
        sa.Column('status', sa.Enum('PENDING', 'ACCEPTED', 'COMPLETED', 'CANCELLED', name='emergencystatus'), nullable=False),
        sa.Column('location_lat', sa.Float(), nullable=False),
        sa.Column('location_lng', sa.Float(), nullable=False),
        sa.Column('assigned_org_id', sa.UUID(), nullable=True),
        sa.Column('assigned_volunteer_id', sa.UUID(), nullable=True),
        sa.Column('rejected_org_ids', sa.JSON(), nullable=False),
        sa.Column('volunteer_history', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),

        sa.ForeignKeyConstraint(['assigned_org_id'], ['accounts.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['assigned_volunteer_id'], ['accounts.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # 6. Family Groups
    op.create_table(
        'family_groups',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('group_name', sa.String(length=255), nullable=False),
        sa.Column('creator_id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['creator_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # 7. Family Members
    op.create_table(
        'family_members',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('family_id', sa.UUID(), nullable=False),
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('relationship', sa.String(length=50), nullable=False),
        sa.Column('added_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['family_id'], ['family_groups.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # 8. Family Alerts
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
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
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
