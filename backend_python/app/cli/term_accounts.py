import typer
from rich.console import Console

from app.database import SessionLocal

app     = typer.Typer(help="Manage term accounts (FD / PPF)")
console = Console()


@app.command("open-fd")
def open_fd(
    user_id:        int   = typer.Option(..., prompt=True,  help="Owner user ID"),
    parent_id:      int   = typer.Option(..., prompt=True,  help="Parent savings/current account ID"),
    amount:         float = typer.Option(..., prompt=True,  help="Principal amount (₹)"),
    interest_rate:  float = typer.Option(..., prompt=True,  help="Annual interest rate (%)"),
    tenure_days:    int   = typer.Option(..., prompt=True,  help="Tenure in days"),
    open_date:      str   = typer.Option(..., prompt=True,  help="Open date (YYYY-MM-DD)"),
    account_number: str   = typer.Option("",  prompt=False, help="FD account/reference number"),
    maturity_amount: float = typer.Option(0.0, prompt=False, help="Maturity amount (0 = auto-calculate)"),
):
    """Open a new Fixed Deposit and debit the parent account."""
    from datetime import date as _date

    from app.commands.fd import fd_open
    from app.models.account import Account, AccountType
    from app.models.term_account import TermAccount, TermAccountType

    try:
        parsed_date = _date.fromisoformat(open_date)
    except ValueError:
        typer.echo("Invalid date format. Use YYYY-MM-DD.", err=True)
        raise typer.Exit(1)

    db = SessionLocal()
    try:
        parent = db.query(Account).filter(
            Account.id == parent_id,
            Account.user_id == user_id,
            Account.account_type.in_([AccountType.savings, AccountType.current]),
        ).first()
        if not parent:
            typer.echo("Parent account not found or not savings/current.", err=True)
            raise typer.Exit(1)

        ta = TermAccount(
            user_id=user_id,
            parent_account_id=parent_id,
            type=TermAccountType.fd,
            account_number=account_number or None,
            amount=amount,
            open_date=parsed_date,
            tenure_days=tenure_days,
            interest_rate=interest_rate,
            maturity_amount=maturity_amount or None,
            balance=0,
        )
        db.add(ta)
        db.flush()

        try:
            fd_open(db, ta, parent, amount, parsed_date, user_id)
        except ValueError as e:
            typer.echo(f"Error: {e}", err=True)
            raise typer.Exit(1)

        db.commit()
        db.refresh(ta)
        console.print(f"  [green]✓[/green] FD #{ta.id} opened — ₹{ta.amount:,.0f} @ {ta.interest_rate}% for {tenure_days}d. Matures {ta.maturity_date} (₹{ta.maturity_amount:,.2f})")
    except typer.Exit:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1)
    finally:
        db.close()


@app.command("close")
def close(
    term_account_id: int   = typer.Argument(..., help="Term account ID to close"),
    user_id:         int   = typer.Option(...,  prompt=True, help="Owner user ID"),
    closed_amount:   float = typer.Option(...,  prompt=True, help="Proceeds credited to savings (₹)"),
    closed_date:     str   = typer.Option(...,  prompt=True, help="Closure date (YYYY-MM-DD)"),
):
    """Close an FD or PPF and credit proceeds to the parent account."""
    from datetime import date as _date

    from app.schemas.term_account import TermAccountClose
    from app.services.term_account_service import close_term_account

    try:
        parsed_date = _date.fromisoformat(closed_date)
    except ValueError:
        typer.echo("Invalid date format. Use YYYY-MM-DD.", err=True)
        raise typer.Exit(1)

    db = SessionLocal()
    try:
        ta = close_term_account(
            db, term_account_id,
            TermAccountClose(closed_date=parsed_date, closed_amount=closed_amount),
            user_id,
        )
        label = "FD" if ta.type.value == "fd" else "PPF"
        console.print(f"  [green]✓[/green] {label} #{ta.id} closed — ₹{ta.closed_amount:,.2f} credited to parent account on {ta.closed_date}")
    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1)
    finally:
        db.close()


@app.command("deposit-ppf")
def deposit_ppf(
    term_account_id: int   = typer.Argument(..., help="PPF term account ID"),
    user_id:         int   = typer.Option(...,  prompt=True, help="Owner user ID"),
    amount:          float = typer.Option(...,  prompt=True, help="Deposit amount (₹)"),
    date:            str   = typer.Option(...,  prompt=True, help="Deposit date (YYYY-MM-DD)"),
):
    """Deposit to a PPF account (debits parent savings account)."""
    from datetime import date as _date

    from app.schemas.term_account import PPFDeposit
    from app.services.term_account_service import deposit_ppf_account

    try:
        parsed_date = _date.fromisoformat(date)
    except ValueError:
        typer.echo("Invalid date format. Use YYYY-MM-DD.", err=True)
        raise typer.Exit(1)

    db = SessionLocal()
    try:
        ta = deposit_ppf_account(db, term_account_id, PPFDeposit(amount=amount, date=parsed_date), user_id)
        console.print(f"  [green]✓[/green] PPF #{ta.id} deposit ₹{amount:,.0f} on {parsed_date}. New balance: ₹{ta.balance:,.2f}")
    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1)
    finally:
        db.close()


@app.command("list")
def list_accounts(
    user_id: int = typer.Option(..., prompt=True, help="Owner user ID"),
):
    """List all term accounts for a user."""
    from app.services.term_account_service import list_term_accounts

    db = SessionLocal()
    try:
        accounts = list_term_accounts(db, user_id)
        if not accounts:
            console.print("  [dim]No term accounts found.[/dim]")
            return
        for ta in accounts:
            status = "[green]active[/green]" if ta.is_active else "[red]closed[/red]"
            console.print(
                f"  #{ta.id}  [{ta.type.value.upper()}]  {ta.bank.short_name}  "
                f"₹{ta.balance:,.0f}  {status}  opened {ta.open_date}"
            )
    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1)
    finally:
        db.close()
