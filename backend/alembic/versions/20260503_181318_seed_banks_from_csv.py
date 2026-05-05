"""seed_banks_from_csv

Revision ID: 49cdf1bf184e
Revises: c5567ab61dea
Create Date: 2026-05-03 18:13:18.469293

"""
from typing import Sequence, Union

from alembic import op

from app.seeds import load_csv_seed

# revision identifiers, used by Alembic.
revision: str = '20260503181318'
down_revision: Union[str, Sequence[str], None] = '20260503134636'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    load_csv_seed("banks", conn, upsert_on="short_name")


def downgrade() -> None:
    raise NotImplementedError("Rollback not supported for seed migrations")
