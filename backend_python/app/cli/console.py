import code
import datetime

import typer
from rich import box
from rich.console import Console
from rich.table import Table


app = typer.Typer(help="Open an interactive console with app context loaded")

_SENSITIVE  = {"hashed_password"}
_PRIORITY   = ["id"]
_TIMESTAMPS = ["created_at", "updated_at"]
_console    = Console()


class _SilentList(list):
    """List that doesn't echo its repr in the REPL (table already printed)."""
    def __repr__(self): return ""


def table(rows, exclude: set[str] = _SENSITIVE) -> "_SilentList":
    """Render a list of ORM objects as a rich table."""
    if rows is None:
        _console.print("[dim]  (no rows)[/dim]")
        return _SilentList()
    if not isinstance(rows, (list, tuple)):
        rows = [rows]
    if not rows:
        _console.print("[dim]  (no rows)[/dim]")
        return _SilentList()

    sample = {k: v for k, v in rows[0].__dict__.items() if not k.startswith("_")}
    cols = [c for c in sample if c not in exclude]
    ordered = (
        [c for c in _PRIORITY if c in cols]
        + [c for c in cols if c not in _PRIORITY and c not in _TIMESTAMPS]
        + [c for c in _TIMESTAMPS if c in cols]
    )

    model_name = type(rows[0]).__name__
    count = len(rows)
    t = Table(
        title=f"[bold green]{model_name}[/bold green]  [dim]{count} row{'s' if count != 1 else ''}[/dim]",
        box=box.ROUNDED,
        header_style="bold cyan",
        border_style="bright_black",
        show_lines=False,
        padding=(0, 1),
    )
    for col in ordered:
        t.add_column(col, overflow="fold", no_wrap=col == "id")
    for row in rows:
        d = row.__dict__
        cells = []
        for col in ordered:
            val = d.get(col)
            if isinstance(val, datetime.datetime):
                cell = val.strftime("%Y-%m-%d %H:%M")
            elif isinstance(val, datetime.date):
                cell = val.strftime("%Y-%m-%d")
            elif val is None:
                cell = "[dim]—[/dim]"
            elif isinstance(val, bool):
                cell = "[green]✓[/green]" if val else "[red]✗[/red]"
            else:
                cell = str(val)
            cells.append(cell)
        t.add_row(*cells)

    _console.print()
    _console.print(t)
    _console.print()
    return _SilentList(rows)


class _ListProxy:
    """Wraps an InstrumentedList so .first / .last / .all / .count work."""

    def __init__(self, rows):
        self._rows = list(rows)

    @property
    def all(self) -> _SilentList:
        return table(self._rows)

    @property
    def first(self):
        if not self._rows:
            _console.print("[dim]  (no rows)[/dim]")
            return None
        row = self._rows[0]
        table([row])
        return _RowProxy(row)

    @property
    def last(self):
        if not self._rows:
            _console.print("[dim]  (no rows)[/dim]")
            return None
        row = self._rows[-1]
        table([row])
        return _RowProxy(row)

    @property
    def count(self) -> int:
        n = len(self._rows)
        _console.print(f"[bold]{n}[/bold]")
        return n

    def __repr__(self):
        n = len(self._rows)
        return f"<list proxy — {n} row{'s' if n != 1 else ''}  |  .all  .first  .last  .count>"


class _RowProxy:
    """Wraps a single ORM row so relationship attributes return _ListProxy."""

    def __init__(self, row):
        object.__setattr__(self, "_row", row)

    def __getattr__(self, name):
        val = getattr(object.__getattribute__(self, "_row"), name)
        # Wrap SQLAlchemy InstrumentedList (relationship collections)
        if hasattr(val, "__iter__") and not isinstance(val, (str, bytes)) and hasattr(val, "append"):
            return _ListProxy(val)
        return val

    def __repr__(self):
        return repr(object.__getattribute__(self, "_row"))


class ModelProxy:
    """
    Rails-style shorthand for a model in the console.

    users.all                          → table of all rows
    users.first                        → first row
    users.count                        → integer count
    users.find(1)                      → row with id=1
    users.where(is_active=True).all    → filtered table
    users.limit(5).all                 → limited table
    users.order_by("created_at").all   → sorted table
    users.order_by("created_at", desc=True).all
    """

    def __init__(self, model, db, query=None):
        self._model = model
        self._db    = db
        self._q     = query if query is not None else db.query(model)

    def _clone(self, new_q):
        return ModelProxy(self._model, self._db, new_q)

    @property
    def all(self) -> _SilentList:
        return table(self._q.all())

    @property
    def first(self):
        row = self._q.first()
        if row:
            table([row])
            return _RowProxy(row)
        _console.print("[dim]  (no rows)[/dim]")
        return None

    @property
    def last(self):
        pk = self._model.__mapper__.primary_key[0]
        row = self._q.order_by(pk.desc()).first()
        if row:
            table([row])
            return _RowProxy(row)
        _console.print("[dim]  (no rows)[/dim]")
        return None

    @property
    def count(self) -> int:
        n = self._q.count()
        _console.print(f"[bold]{n}[/bold]")
        return n

    def find(self, id):
        row = self._db.get(self._model, id)
        if row:
            table([row])
            return _RowProxy(row)
        _console.print(f"[red]  {self._model.__name__} id={id} not found[/red]")
        return None

    def where(self, **kwargs) -> "ModelProxy":
        return self._clone(self._q.filter_by(**kwargs))

    def limit(self, n: int) -> "ModelProxy":
        return self._clone(self._q.limit(n))

    def order_by(self, col: str, desc: bool = False) -> "ModelProxy":
        attr = getattr(self._model, col)
        return self._clone(self._q.order_by(attr.desc() if desc else attr))

    def __repr__(self):
        n = self._q.count()
        return f"<{self._model.__name__} proxy — {n} row{'s' if n != 1 else ''}  |  .all  .first  .count  .find(id)  .where(**kw)  .limit(n)  .order_by(col)>"


@app.callback(invoke_without_command=True)
def console():
    """Drop into a Python REPL with DB session + all models, services, and helpers pre-imported."""
    from app.database import SessionLocal
    from app.models.account import Account
    from app.models.audit import AuditLog
    from app.models.bank import Bank
    from app.models.follio import Follio
    from app.models.instrument import Instrument
    from app.models.investment import Investment, InvestmentType
    from app.models.platform import Platform
    from app.models.platform_account import PlatformAccount
    from app.models.term_account import TermAccount
    from app.models.transaction import LinkedAccountType, Transaction, TransactionType
    from app.models.user import User
    from app.services import auth_service, investment_service, report_service, transaction_service

    db = SessionLocal()

    _console.print()
    _console.rule("[bold green]FinTrack Console[/bold green]")
    _console.print("  [bold]db[/bold]       active SQLAlchemy session")
    _console.print("  [bold]table()[/bold]  pretty-print any ORM list")
    _console.rule(style="bright_black")
    _console.print("  [cyan]Proxies[/cyan]  users  banks  accounts  term_accounts  platforms  platform_accounts")
    _console.print("           instruments  investments  transactions  follios  audit_logs")
    _console.print("  [cyan]Models[/cyan]   User  Bank  Account  TermAccount  Platform  PlatformAccount")
    _console.print("           Instrument  Investment  Transaction  Follio  AuditLog")
    _console.print("  [cyan]Enums[/cyan]    TransactionType  LinkedAccountType  InvestmentType")
    _console.print("  [cyan]Services[/cyan] auth_service  transaction_service")
    _console.print("           investment_service  report_service")
    _console.rule(style="bright_black")
    _console.print("  [dim]users.all[/dim]")
    _console.print("  [dim]users.find(1)[/dim]")
    _console.print("  [dim]users.where(is_active=True).all[/dim]")
    _console.print("  [dim]transactions.where(user_id=1).order_by('date', desc=True).limit(10).all[/dim]")
    _console.print("  [dim]investments.where(user_id=1).count[/dim]")
    _console.print("  [dim]audit_logs.where(table_name='accounts', record_id=1).order_by('changed_at', desc=True).all[/dim]")
    _console.rule(style="bright_black")
    _console.print()

    namespace = {
        # session
        "db": db,
        # helpers
        "table": table,
        # proxies (shorthands)
        "users":             ModelProxy(User,            db),
        "banks":             ModelProxy(Bank,            db),
        "accounts":          ModelProxy(Account,         db),
        "term_accounts":     ModelProxy(TermAccount,     db),
        "platforms":         ModelProxy(Platform,        db),
        "platform_accounts": ModelProxy(PlatformAccount, db),
        "instruments":       ModelProxy(Instrument,      db),
        "investments":       ModelProxy(Investment,      db),
        "transactions":      ModelProxy(Transaction,     db),
        "follios":           ModelProxy(Follio,            db),
        "audit_logs":        ModelProxy(AuditLog, db),
        # model classes (for complex filter expressions)
        "User":              User,
        "Bank":              Bank,
        "Account":           Account,
        "Platform":          Platform,
        "PlatformAccount":   PlatformAccount,
        "Instrument":        Instrument,
        "Investment":        Investment,
        "Transaction":       Transaction,
        "Follio":            Follio,
        "TermAccount":          TermAccount,
        "AuditLog":          AuditLog,
        "TransactionType":   TransactionType,
        "LinkedAccountType": LinkedAccountType,
        "InvestmentType":    InvestmentType,
        # services
        "auth_service":         auth_service,
        "transaction_service":  transaction_service,
        "investment_service":   investment_service,
        "report_service":       report_service,
    }

    try:
        from IPython import start_ipython
        start_ipython(argv=[], user_ns=namespace, display_banner=False)
    except ImportError:
        code.interact(banner="", local=namespace, exitmsg="")
    finally:
        db.close()
