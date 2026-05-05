"""add_open_date_to_accounts

Revision ID: 20260504221651
Revises: 20260504201051
Create Date: 2026-05-04 22:16:51.450102

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260504221651'
down_revision: Union[str, Sequence[str], None] = '20260504201051'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('accounts', sa.Column('open_date', sa.Date(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('accounts', 'open_date')
