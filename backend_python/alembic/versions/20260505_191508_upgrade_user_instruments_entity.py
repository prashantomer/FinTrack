"""upgrade_user_instruments_entity

Revision ID: 20260505191508
Revises: 20260505162335
Create Date: 2026-05-05 19:15:08.468336

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '20260505191508'
down_revision: Union[str, Sequence[str], None] = '20260505162335'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Step 1: Rebuild user_instruments as a proper entity ──────────────────
    # Rename old junction table so we can preserve tracking data
    op.execute("ALTER TABLE user_instruments RENAME TO user_instruments_old")

    op.create_table(
        "user_instruments",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("instrument_id", sa.Integer(), sa.ForeignKey("instruments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("added_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "instrument_id", name="uq_user_instruments_user_instrument"),
    )
    op.create_index("ix_user_instruments_user_id", "user_instruments", ["user_id"])

    # Migrate existing tracking data
    op.execute("""
        INSERT INTO user_instruments (user_id, instrument_id, added_at)
        SELECT user_id, instrument_id, added_at
        FROM user_instruments_old
    """)

    op.execute("DROP TABLE user_instruments_old")

    # ── Step 2: Rebuild follios with new FKs ─────────────────────────────────
    # Drop all existing follios — they reference platform_id + instrument_id
    # which cannot be reliably auto-migrated to user_instrument_id + platform_account_id
    op.execute("TRUNCATE follios")

    op.drop_constraint("uq_follio_user_platform_instrument", "follios", type_="unique")
    op.drop_constraint("follios_platform_id_fkey", "follios", type_="foreignkey")
    op.drop_constraint("follios_instrument_id_fkey", "follios", type_="foreignkey")
    op.drop_column("follios", "platform_id")
    op.drop_column("follios", "instrument_id")

    op.add_column("follios", sa.Column("user_instrument_id", sa.Integer(), nullable=False))
    op.add_column("follios", sa.Column("platform_account_id", sa.Integer(), nullable=False))
    op.create_foreign_key(
        "follios_user_instrument_id_fkey", "follios", "user_instruments",
        ["user_instrument_id"], ["id"], ondelete="CASCADE",
    )
    op.create_foreign_key(
        "follios_platform_account_id_fkey", "follios", "platform_accounts",
        ["platform_account_id"], ["id"], ondelete="CASCADE",
    )
    op.create_index("ix_follios_user_instrument_id", "follios", ["user_instrument_id"])
    op.create_unique_constraint(
        "uq_follio_user_instrument_account", "follios",
        ["user_instrument_id", "platform_account_id"],
    )

    # ── Step 3: Update investments — replace instrument_id with user_instrument_id
    op.drop_index("ix_investments_instrument_id", table_name="investments")
    op.drop_constraint("investments_instrument_id_fkey", "investments", type_="foreignkey")
    op.drop_column("investments", "instrument_id")

    op.add_column("investments", sa.Column("user_instrument_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "investments_user_instrument_id_fkey", "investments", "user_instruments",
        ["user_instrument_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_investments_user_instrument_id", "investments", ["user_instrument_id"])

    # Migrate existing investments: link to user_instrument where possible
    op.execute("""
        UPDATE investments i
        SET user_instrument_id = ui.id
        FROM user_instruments ui
        WHERE ui.user_id = i.user_id
          AND ui.instrument_id IS NOT NULL
    """)


def downgrade() -> None:
    raise NotImplementedError("no downgrade")
