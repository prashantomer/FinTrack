"""user_first_last_superuser_account_balance_txn_category_public_id_follio_investment_public_id

Revision ID: c5567ab61dea
Revises: a98f6a8ed003
Create Date: 2026-05-03 13:46:36.595145

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '20260503134636'
down_revision: Union[str, Sequence[str], None] = '20260503122648'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── follios table ────────────────────────────────────────────────────────
    op.create_table(
        'follios',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('follio_id', sa.String(length=100), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('platform_id', sa.Integer(), nullable=False),
        sa.Column('instrument_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['instrument_id'], ['instruments.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['platform_id'], ['platforms.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'platform_id', 'instrument_id', name='uq_follio_user_platform_instrument'),
    )
    op.create_index(op.f('ix_follios_user_id'), 'follios', ['user_id'], unique=False)

    # ── accounts.balance ─────────────────────────────────────────────────────
    op.add_column('accounts', sa.Column('balance', sa.Numeric(precision=14, scale=2),
                                        nullable=False, server_default='0'))
    op.alter_column('accounts', 'balance', server_default=None)

    # ── investments.transaction_public_id ────────────────────────────────────
    op.add_column('investments', sa.Column('transaction_public_id', sa.UUID(), nullable=True))
    op.create_index(op.f('ix_investments_transaction_public_id'), 'investments', ['transaction_public_id'], unique=False)

    # ── transactions.category + public_id ────────────────────────────────────
    transaction_category = sa.Enum(
        'salary', 'rent', 'groceries', 'utilities', 'dining', 'leisure',
        'investment', 'dividend', 'transfer', 'other',
        name='transaction_category',
    )
    transaction_category.create(op.get_bind(), checkfirst=True)
    op.add_column('transactions', sa.Column('category', transaction_category, nullable=True))
    op.add_column('transactions', sa.Column('public_id', sa.UUID(), nullable=True))
    op.create_index(op.f('ix_transactions_category'), 'transactions', ['category'], unique=False)
    op.create_unique_constraint('uq_transactions_public_id', 'transactions', ['public_id'])

    # ── users: first_name, last_name, is_superuser ───────────────────────────
    # Add as nullable first so existing rows don't violate NOT NULL
    op.add_column('users', sa.Column('first_name', sa.String(), nullable=True))
    op.add_column('users', sa.Column('last_name', sa.String(), nullable=True))
    op.add_column('users', sa.Column('is_superuser', sa.Boolean(), nullable=True))

    # Migrate data: split full_name into first_name / last_name
    op.execute("""
        UPDATE users
        SET
            first_name   = split_part(full_name, ' ', 1),
            last_name    = CASE
                               WHEN position(' ' IN full_name) > 0
                               THEN substr(full_name, position(' ' IN full_name) + 1)
                               ELSE ''
                           END,
            is_superuser = false
    """)

    # Enforce NOT NULL now that all rows are populated
    op.alter_column('users', 'first_name', nullable=False)
    op.alter_column('users', 'last_name', nullable=False)
    op.alter_column('users', 'is_superuser', nullable=False)

    op.drop_column('users', 'full_name')


def downgrade() -> None:
    op.add_column('users', sa.Column('full_name', sa.VARCHAR(), autoincrement=False, nullable=True))
    op.execute("UPDATE users SET full_name = first_name || ' ' || last_name")
    op.alter_column('users', 'full_name', nullable=False)
    op.drop_column('users', 'is_superuser')
    op.drop_column('users', 'last_name')
    op.drop_column('users', 'first_name')
    op.drop_constraint('uq_transactions_public_id', 'transactions', type_='unique')
    op.drop_index(op.f('ix_transactions_category'), table_name='transactions')
    op.drop_column('transactions', 'public_id')
    op.drop_column('transactions', 'category')
    op.execute("DROP TYPE IF EXISTS transaction_category")
    op.drop_index(op.f('ix_investments_transaction_public_id'), table_name='investments')
    op.drop_column('investments', 'transaction_public_id')
    op.drop_column('accounts', 'balance')
    op.drop_index(op.f('ix_follios_user_id'), table_name='follios')
    op.drop_table('follios')
