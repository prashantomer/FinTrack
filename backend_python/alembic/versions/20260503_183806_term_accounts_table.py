"""term_accounts_table

Revision ID: 20260503183806
Revises: 20260503183753
Create Date: 2026-05-03 18:38:06.365779

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = '20260503183806'
down_revision: Union[str, Sequence[str], None] = '20260503183753'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("CREATE TYPE term_account_type AS ENUM ('fd', 'ppf')")
    op.create_table(
        'term_accounts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('bank_id', sa.Integer(), nullable=False),
        sa.Column('parent_account_id', sa.Integer(), nullable=False),
        sa.Column('type', postgresql.ENUM('fd', 'ppf', name='term_account_type', create_type=False), nullable=False),
        sa.Column('account_number', sa.String(100), nullable=True),
        sa.Column('amount', sa.Numeric(14, 2), nullable=False),
        sa.Column('open_date', sa.Date(), nullable=False),
        sa.Column('tenure_days', sa.Integer(), nullable=True),
        sa.Column('interest_rate', sa.Numeric(5, 2), nullable=False),
        sa.Column('maturity_date', sa.Date(), nullable=False),
        sa.Column('maturity_amount', sa.Numeric(14, 2), nullable=False),
        sa.Column('balance', sa.Numeric(14, 2), nullable=False, server_default='0'),
        sa.Column('closed_date', sa.Date(), nullable=True),
        sa.Column('closed_amount', sa.Numeric(14, 2), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['bank_id'], ['banks.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['parent_account_id'], ['accounts.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_term_accounts_user_id', 'term_accounts', ['user_id'])


def downgrade() -> None:
    raise NotImplementedError("Rollback not supported")
