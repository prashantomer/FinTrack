"""bank_short_name_max_6_chars_accounts_closure_cols

Revision ID: 20260503183753
Revises: 20260503181318
Create Date: 2026-05-03 18:37:53.026931

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

from app.seeds import load_csv_seed

revision: str = '20260503183753'
down_revision: Union[str, Sequence[str], None] = '20260503181318'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE banks SET short_name = 'INDUS' WHERE short_name = 'INDUSIND'")
    op.alter_column('banks', 'short_name',
                    existing_type=sa.String(20),
                    type_=sa.String(6),
                    existing_nullable=False)
    op.add_column('accounts', sa.Column('closed_date', sa.Date(), nullable=True))
    op.add_column('accounts', sa.Column('closed_amount', sa.Numeric(14, 2), nullable=True))
    load_csv_seed("banks", op.get_bind(), upsert_on="short_name")


def downgrade() -> None:
    raise NotImplementedError("Rollback not supported")
