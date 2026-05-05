import typer

from app.database import SessionLocal
from app.services.platform_service import create_platform, list_platforms

app = typer.Typer(help="Manage investment platforms (admin only)")

SEED_PLATFORMS = [
    ("Zerodha", "ZERODHA", "broker"),
    ("Groww", "GROWW", "mf_platform"),
    ("Kite by Zerodha", "KITE", "broker"),
    ("Upstox", "UPSTOX", "broker"),
    ("Angel One", "ANGEL", "broker"),
    ("HDFC Securities", "HDFCSEC", "broker"),
    ("ICICI Direct", "ICICIDIRECT", "broker"),
    ("Coin by Zerodha", "COIN", "mf_platform"),
    ("MF Central", "MFCENTRAL", "mf_platform"),
    ("Paytm Money", "PAYTMMONEY", "mf_platform"),
    ("Direct (AMC)", "DIRECT", "direct"),
]


@app.command()
def seed():
    """Seed the database with common investment platforms."""
    db = SessionLocal()
    try:
        existing = {p.short_name for p in list_platforms(db)}
        added = 0
        for name, short_name, ptype in SEED_PLATFORMS:
            if short_name not in existing:
                create_platform(db, name=name, short_name=short_name, type=ptype, is_system=True)
                typer.echo(f"  Added: {name} ({short_name}) [{ptype}]")
                added += 1
            else:
                typer.echo(f"  Skipped (exists): {short_name}")
        typer.echo(f"\nDone. {added} platform(s) added.")
    finally:
        db.close()


@app.command()
def create(
    name: str = typer.Option(..., prompt=True),
    short_name: str = typer.Option(..., prompt=True),
    type: str = typer.Option("broker", prompt=True, help="broker | mf_platform | direct | other"),
):
    """Add a custom platform."""
    db = SessionLocal()
    try:
        p = create_platform(db, name=name, short_name=short_name.upper(), type=type, is_system=False)
        typer.echo(f"Platform created: {p.name} ({p.short_name}) [{p.type}] id={p.id}")
    finally:
        db.close()


@app.command(name="list")
def list_all():
    """List all platforms."""
    db = SessionLocal()
    try:
        platforms = list_platforms(db)
        if not platforms:
            typer.echo("No platforms found.")
            return
        for p in platforms:
            flag = "[system]" if p.is_system else "[custom]"
            typer.echo(f"  {p.id:3d}  {p.short_name:<12} {p.name:<30} [{p.type}] {flag}")
    finally:
        db.close()
