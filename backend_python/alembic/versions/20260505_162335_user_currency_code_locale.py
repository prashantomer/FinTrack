"""user_currency_code_locale

Revision ID: 20260505162335
Revises: 20260504221651
Create Date: 2026-05-05 16:23:35.559180

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260505162335'
down_revision: Union[str, Sequence[str], None] = '20260504221651'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('currency_code', sa.String(length=10), nullable=False, server_default=sa.text("'INR'")))
    op.add_column('users', sa.Column('currency_locale', sa.String(length=20), nullable=False, server_default=sa.text("'en-IN'")))


def downgrade() -> None:
    raise NotImplementedError("no downgrade")
