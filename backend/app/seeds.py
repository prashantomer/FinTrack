import csv
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.engine import Connection
from sqlalchemy.orm import Session

SEEDS_DIR = Path(__file__).resolve().parent.parent / "seeds"


def load_csv_seed(table_name: str, conn: Session | Connection, upsert_on: str | None = None) -> int:
    """Load seed data from seeds/<table_name>.csv into the given table.

    Rows with is_active=false in the CSV are skipped.
    The is_active column is CSV-only and never written to the DB.

    upsert_on:
      None (default) — TRUNCATE + INSERT. Use for tables with no FK dependents.
      str            — INSERT ... ON CONFLICT (col) DO UPDATE. Use for reference tables
                       that other tables FK into (e.g. banks → accounts). Rows not in
                       the CSV are left untouched; rows marked inactive in CSV are skipped
                       (not deleted from DB).

    `conn` can be a SQLAlchemy Session or Connection.
    The caller is responsible for committing when passing a Session.
    """
    csv_path = SEEDS_DIR / f"{table_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Seed file not found: {csv_path}")

    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        rows = [
            {k: _coerce(v) for k, v in row.items() if k != "is_active"}
            for row in reader
            if row.get("is_active", "true").strip().lower() != "false"
        ]

    if upsert_on is None:
        conn.execute(text(f"TRUNCATE TABLE {table_name} RESTART IDENTITY"))  # noqa: S608
        for row in rows:
            cols = ", ".join(row.keys())
            placeholders = ", ".join(f":{k}" for k in row.keys())
            conn.execute(
                text(f"INSERT INTO {table_name} ({cols}) VALUES ({placeholders})"),  # noqa: S608
                row,
            )
    else:
        for row in rows:
            existing = conn.execute(
                text(f"SELECT id FROM {table_name} WHERE {upsert_on} = :val"),  # noqa: S608
                {"val": row[upsert_on]},
            ).fetchone()
            if existing:
                updates = ", ".join(
                    f"{k} = :{k}" for k in row.keys() if k != upsert_on
                )
                conn.execute(
                    text(  # noqa: S608
                        f"UPDATE {table_name} SET {updates}"
                        f" WHERE {upsert_on} = :_match"
                    ),
                    {**row, "_match": row[upsert_on]},
                )
            else:
                cols = ", ".join(row.keys())
                placeholders = ", ".join(f":{k}" for k in row.keys())
                conn.execute(
                    text(f"INSERT INTO {table_name} ({cols}) VALUES ({placeholders})"),  # noqa: S608
                    row,
                )

    return len(rows)


def _coerce(value: str):
    """Convert CSV string values to Python types."""
    stripped = value.strip()
    if stripped.lower() == "true":
        return True
    if stripped.lower() == "false":
        return False
    return stripped or None
