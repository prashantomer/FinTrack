"""backfill transaction date from created_at

Revision ID: 20260504182657
Revises: 20260504182418
Create Date: 2026-05-04 18:26:57.706770

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260504182657'
down_revision: Union[str, Sequence[str], None] = '20260504182418'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE transactions SET date = created_at")


def downgrade() -> None:
    pass
