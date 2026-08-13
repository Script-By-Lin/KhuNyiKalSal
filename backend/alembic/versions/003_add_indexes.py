"""add indexes

Revision ID: 003_add_indexes
Revises: 002_aligned_schema
Create Date: 2026-08-13 23:52:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '003_add_indexes'
down_revision = '002_aligned_schema'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Organizations indexes
    op.create_index(op.f('ix_organizations_geo_lat'), 'organizations', ['geo_lat'], unique=False)
    op.create_index(op.f('ix_organizations_geo_lng'), 'organizations', ['geo_lng'], unique=False)
    op.create_index(op.f('ix_organizations_category'), 'organizations', ['category'], unique=False)
    op.create_index(op.f('ix_organizations_is_active'), 'organizations', ['is_active'], unique=False)
    
    # Emergencies indexes
    op.create_index(op.f('ix_emergencies_type'), 'emergencies', ['type'], unique=False)
    op.create_index(op.f('ix_emergencies_status'), 'emergencies', ['status'], unique=False)
    op.create_index(op.f('ix_emergencies_location_lat'), 'emergencies', ['location_lat'], unique=False)
    op.create_index(op.f('ix_emergencies_location_lng'), 'emergencies', ['location_lng'], unique=False)
    op.create_index(op.f('ix_emergencies_created_at'), 'emergencies', ['created_at'], unique=False)
    op.create_index(op.f('ix_emergencies_assigned_org_id'), 'emergencies', ['assigned_org_id'], unique=False)
    op.create_index(op.f('ix_emergencies_assigned_volunteer_id'), 'emergencies', ['assigned_volunteer_id'], unique=False)

def downgrade() -> None:
    # Organizations
    op.drop_index(op.f('ix_organizations_is_active'), table_name='organizations')
    op.drop_index(op.f('ix_organizations_category'), table_name='organizations')
    op.drop_index(op.f('ix_organizations_geo_lng'), table_name='organizations')
    op.drop_index(op.f('ix_organizations_geo_lat'), table_name='organizations')
    
    # Emergencies
    op.drop_index(op.f('ix_emergencies_assigned_volunteer_id'), table_name='emergencies')
    op.drop_index(op.f('ix_emergencies_assigned_org_id'), table_name='emergencies')
    op.drop_index(op.f('ix_emergencies_created_at'), table_name='emergencies')
    op.drop_index(op.f('ix_emergencies_location_lng'), table_name='emergencies')
    op.drop_index(op.f('ix_emergencies_location_lat'), table_name='emergencies')
    op.drop_index(op.f('ix_emergencies_status'), table_name='emergencies')
    op.drop_index(op.f('ix_emergencies_type'), table_name='emergencies')
