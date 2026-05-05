"""
Fetch instruments from public data sources and upsert into the instruments table.

Sources:
  - NSE EQUITY_L.csv  — all NSE-listed EQ-series equities (~2300 stocks)
  - AMFI NAVAll.txt   — all direct growth mutual fund schemes (~2500 MFs)

Upsert key: ISIN. Rows without an ISIN are skipped.
Existing rows are updated if name, ticker, or fund_house changed.
No rows are ever deleted.

Log file: logs/instrument_fetch.log
  - Truncated at the start of each manual fetch run (call reset_log() first).
"""

import csv
import io
import logging
from pathlib import Path

import httpx
from sqlalchemy.orm import Session

from app.models.instrument import Instrument
from app.models.investment import InvestmentType

_NSE_URL = "https://archives.nseindia.com/content/equities/EQUITY_L.csv"
_AMFI_URL = "https://www.amfiindia.com/spages/NAVAll.txt"
_HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; FinTrack/1.0)"}
_LOG_PATH = Path(__file__).parent.parent.parent.parent / "logs" / "instrument_fetch.log"

# ── Logger setup ──────────────────────────────────────────────────────────────

_FMT = logging.Formatter(
    fmt="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


def _attach_handler(mode: str = "a") -> None:
    _LOG_PATH.parent.mkdir(exist_ok=True)
    fh = logging.FileHandler(_LOG_PATH, mode=mode, encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(_FMT)
    log.addHandler(fh)


log = logging.getLogger("instrument_fetch")
log.setLevel(logging.DEBUG)
log.propagate = False
_attach_handler()


def reset_log() -> None:
    """Truncate the log file and start fresh. Called once per manual fetch run."""
    for handler in log.handlers[:]:
        handler.close()
        log.removeHandler(handler)
    _attach_handler(mode="w")  # 'w' truncates on open

# ── HTTP helper ───────────────────────────────────────────────────────────────

def _get(url: str) -> str:
    log.info("Fetching %s", url)
    with httpx.Client(headers=_HEADERS, timeout=30, follow_redirects=True) as client:
        resp = client.get(url)
        resp.raise_for_status()
    log.info("Received %d bytes from %s", len(resp.content), url)
    return resp.text

# ── Fetch functions ───────────────────────────────────────────────────────────

def fetch_nse_stocks(db: Session) -> tuple[int, int, int]:
    """Fetch NSE EQ-series equities and upsert. Returns (added, updated, skipped)."""
    log.info("=== NSE stocks fetch started ===")

    text = _get(_NSE_URL)

    existing: dict[str, Instrument] = {
        i.isin: i
        for i in db.query(Instrument)
        .filter(Instrument.isin.isnot(None), Instrument.type == InvestmentType.stock)
        .all()
    }
    log.info("Existing stocks in DB: %d", len(existing))

    to_add: list[Instrument] = []
    updated = skipped = 0

    reader = csv.DictReader(io.StringIO(text), skipinitialspace=True)
    for row in reader:
        series = row.get("SERIES", "").strip()
        if series != "EQ":
            log.debug("SKIP  %-12s  series=%s (not EQ)", row.get("SYMBOL", ""), series)
            skipped += 1
            continue

        isin = row.get("ISIN NUMBER", "").strip()
        if not isin:
            log.debug("SKIP  %-12s  no ISIN", row.get("SYMBOL", ""))
            skipped += 1
            continue

        name = row["NAME OF COMPANY"].strip()
        ticker = row["SYMBOL"].strip()[:20]

        if isin in existing:
            inst = existing[isin]
            changes: list[str] = []
            if inst.name != name:
                changes.append(f"name: {inst.name!r} → {name!r}")
                inst.name = name
            if inst.ticker_symbol != ticker:
                changes.append(f"ticker: {inst.ticker_symbol!r} → {ticker!r}")
                inst.ticker_symbol = ticker
            if changes:
                log.info("UPDATE  stock  %-12s  %s  %s  [%s]", ticker, isin, name, ", ".join(changes))
                updated += 1
            else:
                log.debug("SKIP  %-12s  %s  no change", ticker, isin)
                skipped += 1
        else:
            log.info("ADD   stock  %-12s  %s  %s", ticker, isin, name)
            to_add.append(Instrument(
                name=name,
                type=InvestmentType.stock,
                ticker_symbol=ticker,
                isin=isin,
                exchange="NSE",
            ))

    if to_add:
        db.bulk_save_objects(to_add)
    db.commit()

    log.info("=== NSE stocks done — added=%d  updated=%d  skipped=%d ===", len(to_add), updated, skipped)
    return len(to_add), updated, skipped


def fetch_amfi_mutual_funds(db: Session) -> tuple[int, int, int]:
    """Fetch AMFI direct-growth MF schemes and upsert. Returns (added, updated, skipped)."""
    log.info("=== AMFI mutual funds fetch started ===")

    text = _get(_AMFI_URL)

    existing: dict[str, Instrument] = {
        i.isin: i
        for i in db.query(Instrument)
        .filter(Instrument.isin.isnot(None), Instrument.type == InvestmentType.mutual_fund)
        .all()
    }
    log.info("Existing mutual funds in DB: %d", len(existing))

    to_add: list[Instrument] = []
    updated = skipped = 0
    current_amc: str | None = None

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if line.startswith("Scheme Code;"):
            continue

        if ";" not in line:
            if line.startswith(("Open Ended", "Close Ended", "Interval")):
                continue
            current_amc = line.rstrip(";").strip()
            log.debug("AMC: %s", current_amc)
            continue

        parts = line.split(";")
        if len(parts) < 4:
            log.debug("SKIP  malformed line: %s", line[:80])
            skipped += 1
            continue

        scheme_name = parts[3].strip()
        name_lower = scheme_name.lower()

        if "direct" not in name_lower or "growth" not in name_lower:
            log.debug("SKIP  not direct-growth: %s", scheme_name[:80])
            skipped += 1
            continue

        isin = parts[1].strip()
        if not isin or isin == "-":
            isin = parts[2].strip()
        if not isin or isin == "-":
            log.debug("SKIP  no ISIN: %s", scheme_name[:80])
            skipped += 1
            continue

        fund_house = current_amc[:100] if current_amc else None
        name = scheme_name[:255]

        if isin in existing:
            inst = existing[isin]
            changes: list[str] = []
            if inst.name != name:
                changes.append(f"name: {inst.name!r} → {name!r}")
                inst.name = name
            if inst.fund_house != fund_house:
                changes.append(f"fund_house: {inst.fund_house!r} → {fund_house!r}")
                inst.fund_house = fund_house
            if changes:
                log.info("UPDATE  mf  %s  %s  [%s]", isin, name[:60], ", ".join(changes))
                updated += 1
            else:
                log.debug("SKIP  %s  %s  no change", isin, name[:60])
                skipped += 1
        else:
            log.info("ADD   mf  %s  %-30s  %s", isin, (fund_house or ""), name[:60])
            to_add.append(Instrument(
                name=name,
                type=InvestmentType.mutual_fund,
                isin=isin,
                fund_house=fund_house,
            ))

    if to_add:
        db.bulk_save_objects(to_add)
    db.commit()

    log.info("=== AMFI mutual funds done — added=%d  updated=%d  skipped=%d ===", len(to_add), updated, skipped)
    return len(to_add), updated, skipped
