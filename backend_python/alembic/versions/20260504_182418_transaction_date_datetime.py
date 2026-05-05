"""transaction date datetime

Revision ID: 20260504182418
Revises: 20260504145239
Create Date: 2026-05-04 18:24:18.920738

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = '20260504182418'
down_revision: Union[str, Sequence[str], None] = '20260504145239'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE transactions ALTER COLUMN date TYPE TIMESTAMPTZ "
        "USING date::timestamptz"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE transactions ALTER COLUMN date TYPE DATE "
        "USING date::date"
    )
