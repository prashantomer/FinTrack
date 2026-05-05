"""unique_ppf_per_parent_account

Revision ID: 20260504201051
Revises: 20260504195408
Create Date: 2026-05-04 20:10:51.395344

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260504201051'
down_revision: Union[str, Sequence[str], None] = '20260504195408'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        "uq_term_accounts_ppf_per_parent",
        "term_accounts",
        ["user_id", "parent_account_id"],
        unique=True,
        postgresql_where=sa.text("type = 'ppf'"),
    )


def downgrade() -> None:
    op.drop_index("uq_term_accounts_ppf_per_parent", table_name="term_accounts")
