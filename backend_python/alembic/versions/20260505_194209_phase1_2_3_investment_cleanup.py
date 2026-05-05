"""phase1_2_3_investment_cleanup

Revision ID: 20260505194209
Revises: 20260505191508
Create Date: 2026-05-05 19:42:09.048286

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '20260505194209'
down_revision: Union[str, Sequence[str], None] = '20260505191508'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Phase 1 — Remove fixed_deposit and ppf from investment_type enum
    # Guard: ensure no rows exist with these types before removing them
    conn = op.get_bind()
    result = conn.execute(
        sa.text("SELECT COUNT(*) FROM investments WHERE type IN ('fixed_deposit', 'ppf')")
    )
    count = result.scalar()
    if count:
        raise RuntimeError(
            f"Cannot remove fixed_deposit/ppf from enum: {count} investment row(s) still use these types. "
            "Delete or migrate them first."
        )

    # PostgreSQL requires a new enum type to remove values
    op.execute("ALTER TYPE investment_type RENAME TO investment_type_old")
    op.execute(
        "CREATE TYPE investment_type AS ENUM "
        "('stock', 'mutual_fund', 'gold', 'crypto', 'nps', 'real_estate')"
    )
    op.execute(
        "ALTER TABLE investments "
        "ALTER COLUMN type TYPE investment_type USING type::text::investment_type"
    )
    op.execute(
        "ALTER TABLE instruments "
        "ALTER COLUMN type TYPE investment_type USING type::text::investment_type"
    )
    op.execute("DROP TYPE investment_type_old")

    # Phase 2 — Rename avg_buy_price → buy_price
    op.alter_column("investments", "avg_buy_price", new_column_name="buy_price")

    # Phase 3 — Drop FD-specific columns (no longer used)
    op.drop_column("investments", "bank_name")
    op.drop_column("investments", "fd_number")
    op.drop_column("investments", "interest_rate")
    op.drop_column("investments", "tenure_months")
    op.drop_column("investments", "maturity_date")
    op.drop_column("investments", "maturity_amount")
    op.drop_column("investments", "compounding")


def downgrade() -> None:
    raise NotImplementedError("no downgrade")
