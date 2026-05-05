"""replace account_balance_audits with generic audit_logs

Revision ID: 20260504145239
Revises: 20260504124938
Create Date: 2026-05-04 14:52:39.761382

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260504145239'
down_revision: Union[str, Sequence[str], None] = '20260504124938'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_index('ix_account_balance_audits_account_id', table_name='account_balance_audits')
    op.drop_table('account_balance_audits')

    op.create_table(
        'audit_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('table_name', sa.String(length=100), nullable=False),
        sa.Column('record_id', sa.Integer(), nullable=False),
        sa.Column('column_name', sa.String(length=100), nullable=False),
        sa.Column('old_value', sa.Text(), nullable=True),
        sa.Column('new_value', sa.Text(), nullable=True),
        sa.Column('changed_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_audit_logs_table_name', 'audit_logs', ['table_name'])
    op.create_index('ix_audit_logs_record_id', 'audit_logs', ['record_id'])
    op.create_index('ix_audit_logs_table_record', 'audit_logs', ['table_name', 'record_id'])


def downgrade() -> None:
    raise NotImplementedError("Rollback not supported")
