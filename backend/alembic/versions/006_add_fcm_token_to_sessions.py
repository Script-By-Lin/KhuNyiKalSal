"""add fcm_token column to sessions table

Revision ID: 006_add_fcm_token
Revises: 005_add_sessions
Create Date: 2026-08-14 15:25:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '006_add_fcm_token'
down_revision = '005_add_sessions'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [c['name'] for c in inspector.get_columns('sessions')] if inspector.has_table('sessions') else []
    
    if 'fcm_token' not in columns:
        op.add_column('sessions', sa.Column('fcm_token', sa.String(length=500), nullable=True))
        op.create_index('ix_sessions_fcm_token', 'sessions', ['fcm_token'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_sessions_fcm_token', table_name='sessions')
    op.drop_column('sessions', 'fcm_token')
