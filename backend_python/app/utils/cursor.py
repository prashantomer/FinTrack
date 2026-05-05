"""Cursor-based pagination helpers for (date DESC, id DESC) ordering."""
import base64
from datetime import date


def encode_cursor(txn_date: date, txn_id: int) -> str:
    raw = f"{txn_date.isoformat()}:{txn_id}"
    return base64.urlsafe_b64encode(raw.encode()).decode()


def decode_cursor(cursor: str) -> tuple[date, int]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode()).decode()
        date_str, id_str = raw.rsplit(":", 1)
        return date.fromisoformat(date_str), int(id_str)
    except Exception:
        raise ValueError(f"Invalid cursor: {cursor!r}")
