"""transaction_credit_debit_polymorphic_tags

Revision ID: 20260503183808
Revises: 20260503183806
Create Date: 2026-05-03 18:38:09.004011

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = '20260503183808'
down_revision: Union[str, Sequence[str], None] = '20260503183806'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. New enums
    op.execute("CREATE TYPE linked_account_type AS ENUM ('account', 'term_account')")
    op.execute("CREATE TYPE transaction_type_new AS ENUM ('credit', 'debit')")

    # 2. Add new columns
    op.add_column('transactions', sa.Column(
        'linked_account_type',
        postgresql.ENUM('account', 'term_account', name='linked_account_type', create_type=False),
        nullable=True,
    ))
    op.add_column('transactions', sa.Column('linked_account_id', sa.Integer(), nullable=True))
    op.add_column('transactions', sa.Column('tags', postgresql.ARRAY(sa.Text()), nullable=True))
    op.add_column('transactions', sa.Column('bank_ref', sa.String(100), nullable=True))
    op.add_column('transactions', sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'))

    # 3. Migrate account_id → polymorphic pair
    op.execute("""
        UPDATE transactions
        SET linked_account_type = 'account', linked_account_id = account_id
        WHERE account_id IS NOT NULL
    """)

    # 4. Merge notes into description
    op.execute("""
        UPDATE transactions
        SET description = CASE
            WHEN description IS NULL THEN notes
            WHEN notes IS NOT NULL THEN description || ' | ' || notes
            ELSE description
        END
        WHERE notes IS NOT NULL
    """)

    # 5. Carry category into tags array
    op.execute("""
        UPDATE transactions
        SET tags = ARRAY[category::text]
        WHERE category IS NOT NULL
    """)

    # 6. Rename transaction_type enum values (inbound→credit, outbound→debit)
    op.execute("""
        ALTER TABLE transactions
        ALTER COLUMN type TYPE transaction_type_new
        USING (CASE type::text WHEN 'inbound' THEN 'credit' ELSE 'debit' END)::transaction_type_new
    """)
    op.execute("DROP TYPE transaction_type")
    op.execute("ALTER TYPE transaction_type_new RENAME TO transaction_type")

    # 7. Drop obsolete columns (drop FK constraint on account_id first)
    op.execute("""
        ALTER TABLE transactions
        DROP CONSTRAINT IF EXISTS transactions_account_id_fkey
    """)
    op.drop_column('transactions', 'account_id')
    op.drop_column('transactions', 'category')
    op.drop_column('transactions', 'notes')
    op.execute("DROP TYPE IF EXISTS transaction_category")

    # 8. Indexes for polymorphic columns
    op.create_index('ix_transactions_linked_account_type', 'transactions', ['linked_account_type'])
    op.create_index('ix_transactions_linked_account_id', 'transactions', ['linked_account_id'])


def downgrade() -> None:
    raise NotImplementedError("Rollback not supported")
