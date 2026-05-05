import secrets

import typer
from sqlalchemy.exc import IntegrityError

from app.database import SessionLocal
from app.models.account import Account
from app.models.audit import AuditLog
from app.models.follio import Follio
from app.models.investment import Investment
from app.models.platform_account import PlatformAccount
from app.models.term_account import TermAccount
from app.models.transaction import Transaction
from app.services.auth_service import create_user, get_user_by_email

app = typer.Typer(help="User management commands")

# Common currencies: (display label, currency_code, currency_locale)
_CURRENCIES = [
    ("INR  – Indian Rupee       ₹  (e.g. ₹1,23,456)",  "INR",  "en-IN"),
    ("USD  – US Dollar          $  (e.g. $1,234)",      "USD",  "en-US"),
    ("EUR  – Euro               €  (e.g. €1.234)",      "EUR",  "de-DE"),
    ("GBP  – British Pound      £  (e.g. £1,234)",      "GBP",  "en-GB"),
    ("JPY  – Japanese Yen       ¥  (e.g. ¥123,456)",    "JPY",  "ja-JP"),
    ("AUD  – Australian Dollar  A$ (e.g. A$1,234)",     "AUD",  "en-AU"),
    ("CAD  – Canadian Dollar    C$ (e.g. C$1,234)",     "CAD",  "en-CA"),
    ("SGD  – Singapore Dollar   S$ (e.g. S$1,234)",     "SGD",  "en-SG"),
    ("AED  – UAE Dirham         د.إ (e.g. AED 1,234)",  "AED",  "ar-AE"),
    ("Other – enter manually",                           None,   None),
]


def _pick_currency() -> tuple[str, str]:
    """Interactive currency selector. Returns (currency_code, currency_locale)."""
    typer.echo("\nCurrency:")
    for i, (label, _, _) in enumerate(_CURRENCIES, 1):
        typer.echo(f"  {i:>2}.  {label}")

    while True:
        raw = typer.prompt(f"\nSelect [1-{len(_CURRENCIES)}]", default="1")
        try:
            choice = int(raw)
        except ValueError:
            typer.echo("  Please enter a number.")
            continue
        if not 1 <= choice <= len(_CURRENCIES):
            typer.echo(f"  Please enter a number between 1 and {len(_CURRENCIES)}.")
            continue

        _, code, locale = _CURRENCIES[choice - 1]
        if code is None:
            code   = typer.prompt("  Currency code   (e.g. CHF, MXN, BRL)")
            locale = typer.prompt("  Locale          (e.g. de-CH, es-MX, pt-BR)")
        return code, locale


@app.command("create")
def create_user_cmd(
    generate: bool = typer.Option(False, "--generate", help="Auto-generate a random password"),
):
    """Create a new user. Prompts for email, first name, last name, password, and currency."""
    email      = typer.prompt("Email")
    first_name = typer.prompt("First name")
    last_name  = typer.prompt("Last name")

    if generate:
        password = secrets.token_urlsafe(16)
    else:
        password = typer.prompt("Password", hide_input=True, confirmation_prompt=True)

    currency_code, currency_locale = _pick_currency()

    db = SessionLocal()
    try:
        if get_user_by_email(db, email):
            typer.echo(f"Error: a user with email '{email}' already exists.", err=True)
            raise typer.Exit(code=1)
        create_user(
            db,
            email=email,
            first_name=first_name,
            last_name=last_name,
            password=password,
            currency_code=currency_code,
            currency_locale=currency_locale,
        )
        typer.echo("\nUser created successfully")
        typer.echo(f"  Email:    {email}")
        typer.echo(f"  Name:     {first_name} {last_name}")
        typer.echo(f"  Currency: {currency_code}  ({currency_locale})")
        typer.echo(f"  Password: {password}")
    except IntegrityError:
        db.rollback()
        typer.echo("Error: could not create user (duplicate email).", err=True)
        raise typer.Exit(code=1)
    finally:
        db.close()


_BOLD  = lambda s: typer.style(str(s), bold=True)
_DIM   = lambda s: typer.style(str(s), dim=True)
_GREEN = lambda s: typer.style(str(s), fg=typer.colors.GREEN)
_RED   = lambda s: typer.style(str(s), fg=typer.colors.RED)


def _ask(prompt: str) -> str:
    """Prompt until the user enters y / n / a (case-insensitive)."""
    while True:
        raw = typer.prompt(f"  {prompt} [Y/n/a]", default="n").strip().lower()
        if raw in ("y", "n", "a"):
            return raw
        typer.echo("  Please enter y (yes), n (skip), or a (abort).")


@app.command("wipe")
def wipe_user_cmd(
    fast: bool = typer.Option(False, "--fast", "-f", help="Skip per-step prompts — confirm once and wipe all."),
):
    """
    Wipe financial data for a user.

    Default: step through each category with Y / N / A.
    --fast:  show summary, confirm once, delete everything.
    """
    email = typer.prompt("Email")

    db = SessionLocal()
    try:
        user = get_user_by_email(db, email)
        if not user:
            typer.echo(f"Error: no user found with email '{email}'.", err=True)
            raise typer.Exit(code=1)

        accounts      = db.query(Account).filter(Account.user_id == user.id).all()
        term_accounts = db.query(TermAccount).filter(TermAccount.user_id == user.id).all()
        transactions  = db.query(Transaction).filter(Transaction.user_id == user.id).all()
        investments   = db.query(Investment).filter(Investment.user_id == user.id).all()
        platform_accs = db.query(PlatformAccount).filter(PlatformAccount.user_id == user.id).all()
        follios       = db.query(Follio).filter(Follio.user_id == user.id).all()

        # Least critical first → most critical last
        categories = [
            ("Follios", follios, [
                f"#{f.id}  {f.follio_id}"
                for f in follios
            ]),
            ("Platform accounts", platform_accs, [
                f"#{p.id}  {p.platform.name if p.platform else '—':<20}  {p.nickname}"
                for p in platform_accs
            ]),
            ("Investments", investments, [
                f"#{i.id}  {i.type.value:<15}  {i.name}"
                for i in investments
            ]),
            ("Transactions", transactions, [
                f"#{t.id}  {t.date}  {t.type.value:<6}  ₹{t.amount:>12,.2f}  {t.description or '—'}"
                for t in transactions
            ]),
            ("Term accounts", term_accounts, [
                f"#{t.id}  {t.type.value.upper():<3}  {t.account_number or '—':<24}  ₹{t.balance:>12,.2f}  {'active' if t.is_active else 'closed'}"
                for t in term_accounts
            ]),
            ("Accounts", accounts, [
                f"#{a.id}  {a.bank.short_name:<6}  {a.nickname:<20}  ₹{a.balance:>12,.2f}  {a.account_type.value}"
                for a in accounts
            ]),
        ]
        total = sum(len(r) for _, r, _ in categories)

        if total == 0:
            typer.echo(f"\nNo data found for {email}.")
            return

        # ── Summary header ────────────────────────────────────────────────────
        typer.echo(f"\nData for {_BOLD(email)}:\n")
        w = max(len(label) for label, _, _ in categories)
        for label, rows, _ in categories:
            count = str(len(rows)) if rows else _DIM("none")
            typer.echo(f"  {label:<{w}}  {count}")
        typer.echo(f"  {'─' * w}  ────")
        typer.echo(f"  {'Total':<{w}}  {_BOLD(total)}")

        # ── Fast wipe: single confirmation ───────────────────────────────────
        if fast:
            typer.echo("")
            choice = _ask(f"Wipe ALL {total} records?")
            if choice != "y":
                typer.echo(_RED("\nAborted. Nothing deleted.") if choice == "a" else "\nNothing deleted.")
                return
            ta_ids   = [t.id for t in term_accounts]
            acct_ids = [a.id for a in accounts]
            db.query(AuditLog).filter(AuditLog.table_name == "term_accounts", AuditLog.record_id.in_(ta_ids)).delete(synchronize_session=False)
            db.query(AuditLog).filter(AuditLog.table_name == "accounts",      AuditLog.record_id.in_(acct_ids)).delete(synchronize_session=False)
            db.query(Follio).filter(Follio.user_id == user.id).delete(synchronize_session=False)
            db.query(PlatformAccount).filter(PlatformAccount.user_id == user.id).delete(synchronize_session=False)
            db.query(Investment).filter(Investment.user_id == user.id).delete(synchronize_session=False)
            db.query(Transaction).filter(Transaction.user_id == user.id).delete(synchronize_session=False)
            db.query(TermAccount).filter(TermAccount.user_id == user.id).delete(synchronize_session=False)
            db.query(Account).filter(Account.user_id == user.id).delete(synchronize_session=False)
            db.commit()
            typer.echo(_BOLD(_GREEN(f"\nDone — {total} records deleted.")))
            return

        # ── Step through each category ────────────────────────────────────────
        wiped = 0
        step_total = sum(1 for _, r, _ in categories if r)

        for step, (label, rows, lines) in enumerate(
            (x for x in categories if x[1]), start=1
        ):
            typer.echo(f"\n{'─' * 50}")
            typer.echo(f"  Step {step}/{step_total}  {_BOLD(label)}  ({len(rows)} records)\n")
            for line in lines[:20]:
                typer.echo(f"    {line}")
            if len(lines) > 20:
                typer.echo(_DIM(f"    … and {len(lines) - 20} more"))

            choice = _ask(f"Wipe {label}?")

            if choice == "a":
                if wiped:
                    db.commit()
                typer.echo(_RED(f"\nAborted. {wiped} records already deleted were committed."))
                return

            if choice == "n":
                typer.echo(f"  {_DIM('↷ Skipped')}")
                continue

            # y — execute this step
            if label == "Transactions":
                n = db.query(Transaction).filter(Transaction.user_id == user.id).delete(synchronize_session=False)
            elif label == "Term accounts":
                ta_ids = [t.id for t in term_accounts]
                db.query(AuditLog).filter(AuditLog.table_name == "term_accounts", AuditLog.record_id.in_(ta_ids)).delete(synchronize_session=False)
                n = db.query(TermAccount).filter(TermAccount.user_id == user.id).delete(synchronize_session=False)
            elif label == "Accounts":
                acct_ids = [a.id for a in accounts]
                db.query(AuditLog).filter(AuditLog.table_name == "accounts", AuditLog.record_id.in_(acct_ids)).delete(synchronize_session=False)
                n = db.query(Account).filter(Account.user_id == user.id).delete(synchronize_session=False)
            elif label == "Investments":
                n = db.query(Investment).filter(Investment.user_id == user.id).delete(synchronize_session=False)
            elif label == "Platform accounts":
                n = db.query(PlatformAccount).filter(PlatformAccount.user_id == user.id).delete(synchronize_session=False)
            elif label == "Follios":
                n = db.query(Follio).filter(Follio.user_id == user.id).delete(synchronize_session=False)

            db.flush()
            wiped += n
            typer.echo(_GREEN(f"  ✓ Deleted {n} {label.lower()}"))

        typer.echo(f"\n{'─' * 50}")
        if wiped:
            db.commit()
            typer.echo(_BOLD(_GREEN(f"\nDone — {wiped} records deleted.")))
        else:
            typer.echo("\nNothing deleted.")
    finally:
        db.close()
