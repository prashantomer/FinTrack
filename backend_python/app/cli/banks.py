import typer

from app.database import SessionLocal
from app.seeds import load_csv_seed
from app.services.bank_service import create_bank, list_banks

app = typer.Typer(help="Manage banks (admin only)")


@app.command()
def seed():
    """Truncate banks table and reload from seeds/banks.csv."""
    db = SessionLocal()
    try:
        count = load_csv_seed("banks", db, upsert_on="short_name")
        db.commit()
        typer.echo(f"Done. {count} bank(s) loaded from CSV.")
    except FileNotFoundError as e:
        typer.echo(str(e), err=True)
        raise typer.Exit(1)
    except Exception as e:
        db.rollback()
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1)
    finally:
        db.close()


@app.command()
def create(
    name: str = typer.Option(..., prompt=True),
    short_name: str = typer.Option(..., prompt=True),
):
    """Add a custom bank."""
    db = SessionLocal()
    try:
        bank = create_bank(db, name=name, short_name=short_name.upper(), is_system=False)
        typer.echo(f"Bank created: {bank.name} ({bank.short_name}) id={bank.id}")
    finally:
        db.close()


@app.command(name="list")
def list_all():
    """List all banks."""
    db = SessionLocal()
    try:
        banks = list_banks(db)
        if not banks:
            typer.echo("No banks found.")
            return
        for b in banks:
            flag = "[system]" if b.is_system else "[custom]"
            typer.echo(f"  {b.id:3d}  {b.short_name:<10} {b.name}  {flag}")
    finally:
        db.close()
