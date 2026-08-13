"""add is_resolved to family alerts

Revision ID: 004_add_is_resolved
Revises: 003_add_indexes
Create Date: 2026-08-14 00:37:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '004_add_is_resolved'
down_revision = '003_add_indexes'
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column('family_alerts', sa.Column('is_resolved', sa.Boolean(), server_default="false", nullable=False))

def downgrade() -> None:
    op.drop_column('family_alerts', 'is_resolved')
