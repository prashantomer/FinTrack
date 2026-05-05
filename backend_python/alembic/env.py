import sys
from datetime import datetime
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from sqlalchemy import engine_from_config, pool

# Make `app` importable when alembic runs from backend/
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import settings  # noqa: E402
from app.database import Base  # noqa: E402

# Import all models so autogenerate detects schema changes
from app.models.user import User  # noqa: F401, E402
from app.models.transaction import Transaction  # noqa: F401, E402
from app.models.investment import Investment  # noqa: F401, E402
from app.models.instrument import Instrument  # noqa: F401, E402
from app.models.account import Account  # noqa: F401, E402
from app.models.audit import AuditLog  # noqa: F401, E402
from app.models.bank import Bank  # noqa: F401, E402
from app.models.term_account import TermAccount  # noqa: F401, E402
from app.models.platform import Platform  # noqa: F401, E402
from app.models.platform_account import PlatformAccount  # noqa: F401, E402

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _set_datetime_rev_id(config, context, revision_directives):
    """Use a datetime stamp (YYYYMMDDHHmmSS) as the revision ID."""
    for directive in revision_directives:
        directive.rev_id = datetime.now().strftime("%Y%m%d%H%M%S")


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        process_revision_directives=_set_datetime_rev_id,
    )
    with context.begin_transaction():
        context.run_migrations()


def _terminate_idle_blockers(connection) -> None:
    """
    Kill sessions that are idle-in-transaction before DDL runs.
    Without this, a single abandoned transaction can block ALTER TABLE
    indefinitely, causing a lock queue that also freezes incoming reads.
    """
    from sqlalchemy import text
    result = connection.execute(text("""
        SELECT pg_terminate_backend(pid), pid, state, left(query, 80) AS query
        FROM pg_stat_activity
        WHERE datname = current_database()
          AND pid <> pg_backend_pid()
          AND state = 'idle in transaction'
    """))
    rows = result.fetchall()
    if rows:
        import logging
        log = logging.getLogger("alembic.env")
        for _, pid, state, query in rows:
            log.warning("Terminated idle-in-transaction session pid=%s query=%r", pid, query)


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        _terminate_idle_blockers(connection)
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            process_revision_directives=_set_datetime_rev_id,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
