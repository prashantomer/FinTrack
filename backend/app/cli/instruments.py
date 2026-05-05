import typer

from app.database import SessionLocal
from app.models.instrument import Instrument
from app.models.investment import InvestmentType

app = typer.Typer(help="Manage instruments (admin only)")

SEED_INSTRUMENTS = [
    # ── Nifty 50 stocks ───────────────────────────────────────────────────────
    dict(name="Reliance Industries",    type=InvestmentType.stock,       ticker_symbol="RELIANCE",  isin="INE002A01018", exchange="NSE"),
    dict(name="HDFC Bank",              type=InvestmentType.stock,       ticker_symbol="HDFCBANK",  isin="INE040A01034", exchange="NSE"),
    dict(name="Infosys",                type=InvestmentType.stock,       ticker_symbol="INFY",      isin="INE009A01021", exchange="NSE"),
    dict(name="TCS",                    type=InvestmentType.stock,       ticker_symbol="TCS",       isin="INE467B01029", exchange="NSE"),
    dict(name="ICICI Bank",             type=InvestmentType.stock,       ticker_symbol="ICICIBANK", isin="INE090A01021", exchange="NSE"),
    dict(name="Kotak Mahindra Bank",    type=InvestmentType.stock,       ticker_symbol="KOTAKBANK", isin="INE237A01028", exchange="NSE"),
    dict(name="Larsen & Toubro",        type=InvestmentType.stock,       ticker_symbol="LT",        isin="INE018A01030", exchange="NSE"),
    dict(name="Axis Bank",              type=InvestmentType.stock,       ticker_symbol="AXISBANK",  isin="INE238A01034", exchange="NSE"),
    dict(name="State Bank of India",    type=InvestmentType.stock,       ticker_symbol="SBIN",      isin="INE062A01020", exchange="NSE"),
    dict(name="Bajaj Finance",          type=InvestmentType.stock,       ticker_symbol="BAJFINANCE",isin="INE296A01024", exchange="NSE"),
    dict(name="Hindustan Unilever",     type=InvestmentType.stock,       ticker_symbol="HINDUNILVR",isin="INE030A01027", exchange="NSE"),
    dict(name="Asian Paints",           type=InvestmentType.stock,       ticker_symbol="ASIANPAINT",isin="INE021A01026", exchange="NSE"),
    dict(name="Maruti Suzuki",          type=InvestmentType.stock,       ticker_symbol="MARUTI",    isin="INE585B01010", exchange="NSE"),
    dict(name="Sun Pharma",             type=InvestmentType.stock,       ticker_symbol="SUNPHARMA", isin="INE044A01036", exchange="NSE"),
    dict(name="Titan Company",          type=InvestmentType.stock,       ticker_symbol="TITAN",     isin="INE280A01028", exchange="NSE"),
    # ── Mutual funds ──────────────────────────────────────────────────────────
    dict(name="Nippon India Nifty 50 Index Fund",     type=InvestmentType.mutual_fund, fund_house="Nippon India MF"),
    dict(name="HDFC Flexi Cap Fund",                  type=InvestmentType.mutual_fund, fund_house="HDFC AMC"),
    dict(name="Mirae Asset Large Cap Fund",           type=InvestmentType.mutual_fund, fund_house="Mirae Asset MF"),
    dict(name="Parag Parikh Flexi Cap Fund",          type=InvestmentType.mutual_fund, fund_house="PPFAS MF"),
    dict(name="Axis Bluechip Fund",                   type=InvestmentType.mutual_fund, fund_house="Axis MF"),
    dict(name="SBI Small Cap Fund",                   type=InvestmentType.mutual_fund, fund_house="SBI MF"),
    dict(name="Kotak Emerging Equity Fund",           type=InvestmentType.mutual_fund, fund_house="Kotak MF"),
    dict(name="ICICI Pru Technology Fund",            type=InvestmentType.mutual_fund, fund_house="ICICI Prudential MF"),
]


@app.command()
def seed():
    """Seed the database with common stocks and mutual funds."""
    db = SessionLocal()
    try:
        existing = {i.name for i in db.query(Instrument).all()}
        added = 0
        for spec in SEED_INSTRUMENTS:
            if spec["name"] in existing:
                typer.echo(f"  Skipped (exists): {spec['name']}")
                continue
            inst = Instrument(**spec)
            db.add(inst)
            db.commit()
            label = spec.get("ticker_symbol") or spec.get("fund_house", "")
            typer.echo(f"  Added: {spec['name']} ({label})")
            added += 1
        typer.echo(f"\nDone. {added} instrument(s) added.")
    finally:
        db.close()


@app.command(name="list")
def list_all(
    type: str = typer.Option(None, "--type", help="Filter by type (stock, mutual_fund, …)"),
):
    """List all instruments."""
    db = SessionLocal()
    try:
        q = db.query(Instrument).order_by(Instrument.type, Instrument.name)
        if type:
            q = q.filter(Instrument.type == type)
        instruments = q.all()
        if not instruments:
            typer.echo("No instruments found.")
            return
        current_type = None
        for i in instruments:
            if i.type != current_type:
                current_type = i.type
                typer.echo(f"\n  [{i.type}]")
            detail = i.ticker_symbol or i.fund_house or "—"
            typer.echo(f"    {i.id:4d}  {detail:<12}  {i.name}")
    finally:
        db.close()
