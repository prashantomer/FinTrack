import typer

from app.database import SessionLocal
from app.models.transaction import TransactionType
from app.services.transaction_service import correct_transaction, deactivate_transaction

app = typer.Typer(help="Manage transactions (admin corrections only)")


@app.command()
def correct(
    transaction_id: int = typer.Argument(..., help="Transaction ID to correct"),
    amount: float = typer.Option(..., prompt=True, help="Corrected amount"),
    type: str = typer.Option(..., prompt=True, help="Corrected type: credit or debit"),
    user_id: int = typer.Option(..., prompt=True, help="Owner user ID"),
):
    """Correct a transaction amount/type and recalculate account balance."""
    try:
        txn_type = TransactionType(type)
    except ValueError:
        typer.echo(f"Invalid type '{type}'. Must be 'credit' or 'debit'.", err=True)
        raise typer.Exit(1)

    db = SessionLocal()
    try:
        t = correct_transaction(db, transaction_id, amount, txn_type, user_id)
        typer.echo(f"Transaction {t.id} corrected: {t.type.value} {t.amount}")
    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1)
    finally:
        db.close()


@app.command()
def deactivate(
    transaction_id: int = typer.Argument(..., help="Transaction ID to deactivate"),
    user_id: int = typer.Option(..., prompt=True, help="Owner user ID"),
):
    """Mark a transaction inactive and reverse its balance impact."""
    db = SessionLocal()
    try:
        t = deactivate_transaction(db, transaction_id, user_id)
        typer.echo(f"Transaction {t.id} deactivated. Balance adjusted.")
    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1)
    finally:
        db.close()
