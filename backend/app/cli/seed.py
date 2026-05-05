"""
Seed realistic test data for development.

Usage:
    uv run python -m app.cli seed data          # seed both users
    uv run python -m app.cli seed data --reset  # wipe and reseed
"""

import uuid
from datetime import date

import typer
from rich.console import Console

from app.database import SessionLocal

app     = typer.Typer(help="Seed test data for development")
console = Console()

# ── User 1 — Prashant Sharma (salaried, conservative) ─────────────────────────
USER1_EMAIL     = "test@fintrack.dev"
USER1_PASSWORD  = "test1234"
USER1_FIRST     = "Prashant"
USER1_LAST      = "Sharma"

# ── User 2 — Ananya Kapoor (freelancer, growth-oriented) ──────────────────────
USER2_EMAIL     = "ananya@fintrack.dev"
USER2_PASSWORD  = "test1234"
USER2_FIRST     = "Ananya"
USER2_LAST      = "Kapoor"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _ok(msg: str):   console.print(f"  [green]✓[/green] {msg}")
def _skip(msg: str): console.print(f"  [dim]–[/dim] {msg}")
def _err(msg: str):  console.print(f"  [red]✗[/red] {msg}")


def _get_bank(db, short_name: str):
    from app.models.bank import Bank
    b = db.query(Bank).filter(Bank.short_name == short_name).first()
    if not b:
        _err(f"Bank '{short_name}' not found — run `uv run python -m app.cli banks seed` first")
    return b


def _get_platform(db, short_name: str):
    from app.models.platform import Platform
    p = db.query(Platform).filter(Platform.short_name == short_name).first()
    if not p:
        _err(f"Platform '{short_name}' not found — run `uv run python -m app.cli platforms seed` first")
    return p


def _resolve_instruments(db, user, names: list[str]) -> dict:
    from app.models.instrument import Instrument, user_instruments

    already_tracked = {
        row.instrument_id
        for row in db.execute(
            user_instruments.select().where(user_instruments.c.user_id == user.id)
        ).fetchall()
    }

    result = {}
    for name in names:
        inst = db.query(Instrument).filter(Instrument.name == name).first()
        if not inst:
            _err(f"Instrument '{name}' not found — run `uv run python -m app.cli instruments seed` first")
            continue
        if inst.id not in already_tracked:
            db.execute(user_instruments.insert().values(user_id=user.id, instrument_id=inst.id))
            db.commit()
            label = inst.ticker_symbol or inst.fund_house or inst.name
            _ok(f"Tracked '{inst.name}' ({label})")
        else:
            _skip(f"Already tracking '{inst.name}'")
        result[name] = inst
    return result


# ────────────────────────────────────────────────────────────────────────────
#  USER 1 — Prashant Sharma
# ────────────────────────────────────────────────────────────────────────────

def _seed_user1(db):
    from app.services.auth_service import create_user, get_user_by_email
    user = get_user_by_email(db, USER1_EMAIL)
    if user:
        _skip(f"User {USER1_EMAIL} already exists (id={user.id})")
        return user
    user = create_user(db, email=USER1_EMAIL, first_name=USER1_FIRST,
                       last_name=USER1_LAST, password=USER1_PASSWORD)
    _ok(f"Created user  {USER1_EMAIL}  (id={user.id})")
    return user


def _seed_user1_accounts(db, user):
    from app.models.account import Account, AccountType

    existing = {a.nickname for a in db.query(Account).filter(Account.user_id == user.id).all()}
    created  = []

    specs = [
        ("HDFC",  "HDFC Primary",  AccountType.savings,  325000.00),
        ("SBI",   "SBI Salary",    AccountType.salary,   348200.00),
        ("ICICI", "ICICI Credit",  AccountType.current,  -12400.00),
    ]

    for short_name, nickname, actype, balance in specs:
        if nickname in existing:
            _skip(f"Account '{nickname}' already exists")
            acct = db.query(Account).filter(
                Account.user_id == user.id, Account.nickname == nickname
            ).first()
            created.append(acct)
            continue
        bank = _get_bank(db, short_name)
        if not bank:
            created.append(None)
            continue
        acct = Account(user_id=user.id, bank_id=bank.id, nickname=nickname,
                       account_type=actype, balance=balance)
        db.add(acct)
        db.commit()
        db.refresh(acct)
        _ok(f"Created account '{nickname}'")
        created.append(acct)

    return created  # [hdfc, sbi, icici]


def _seed_user1_platform_accounts(db, user):
    from app.models.platform_account import PlatformAccount

    existing = {pa.nickname for pa in db.query(PlatformAccount).filter(PlatformAccount.user_id == user.id).all()}
    created  = []

    specs = [
        ("ZERODHA", "Zerodha Trading", "ZER-PS-00123"),
        ("GROWW",   "Groww MF",        "GROWW-9988776"),
    ]

    for short_name, nickname, account_id in specs:
        if nickname in existing:
            _skip(f"Platform account '{nickname}' already exists")
            pa = db.query(PlatformAccount).filter(
                PlatformAccount.user_id == user.id, PlatformAccount.nickname == nickname
            ).first()
            created.append(pa)
            continue
        platform = _get_platform(db, short_name)
        if not platform:
            created.append(None)
            continue
        pa = PlatformAccount(user_id=user.id, platform_id=platform.id,
                             nickname=nickname, account_id=account_id)
        db.add(pa)
        db.commit()
        db.refresh(pa)
        _ok(f"Created platform account '{nickname}'")
        created.append(pa)

    return created  # [zerodha, groww]


def _seed_user1_follios(db, user, platform_accounts, instruments):
    from app.models.follio import Follio

    zerodha, groww = platform_accounts
    if db.query(Follio).filter(Follio.user_id == user.id).count() > 0:
        _skip("Follios already exist — skipping")
        return

    specs = [
        (groww,   "12345678",        "Nippon India Nifty 50 Index Fund"),
        (groww,   "87654321",        "HDFC Flexi Cap Fund"),
        (zerodha, "ZER-RELIANCE-01", "Reliance Industries"),
        (zerodha, "ZER-HDFC-01",     "HDFC Bank"),
        (zerodha, "ZER-INFY-01",     "Infosys"),
    ]
    count = 0
    for pa, follio_id, inst_name in specs:
        if not pa or inst_name not in instruments:
            continue
        inst = instruments[inst_name]
        follio = Follio(
            follio_id=follio_id,
            user_id=user.id,
            platform_id=pa.platform_id,
            instrument_id=inst.id,
        )
        db.add(follio)
        count += 1
    db.commit()
    _ok(f"Created {count} follios")


def _seed_user1_transactions(db, user, accounts, instruments):
    from app.models.transaction import LinkedAccountType, Transaction, TransactionType

    hdfc, sbi, icici = accounts

    if db.query(Transaction).filter(Transaction.user_id == user.id).count() > 0:
        _skip("Transactions (user1) already exist — skipping")
        return

    nifty_inst    = instruments.get("Nippon India Nifty 50 Index Fund")
    hdfcbank_inst = instruments.get("HDFC Bank")

    rows = []

    def txn(acct=None, **kw):
        lat = LinkedAccountType.account if acct else None
        laid = acct.id if acct else None
        return Transaction(user_id=user.id, public_id=uuid.uuid4(),
                           linked_account_type=lat, linked_account_id=laid, **kw)

    # ── Monthly salary ────────────────────────────────────────────────────────
    for d, amt in [(date(2025, 10, 1), 155000), (date(2025, 11, 1), 155000),
                   (date(2025, 12, 1), 155000), (date(2026,  1, 1), 160000),
                   (date(2026,  2, 1), 160000), (date(2026,  3, 1), 160000),
                   (date(2026,  4, 1), 160000)]:
        rows.append(txn(sbi, amount=amt, type=TransactionType.credit,
                        tags=["salary"], description="Monthly salary", date=d))

    # ── Monthly rent ──────────────────────────────────────────────────────────
    for d in [date(2025, 10, 5), date(2025, 11, 5), date(2025, 12, 5),
              date(2026,  1, 5), date(2026,  2, 5), date(2026,  3, 5), date(2026, 4, 5)]:
        rows.append(txn(hdfc, amount=28000, type=TransactionType.debit,
                        tags=["rent"], description="House rent", date=d))

    # ── Groceries ─────────────────────────────────────────────────────────────
    for d, amt in zip(
        [date(2025, 10, 18), date(2025, 11, 17), date(2025, 12, 20),
         date(2026,  1, 19), date(2026,  2, 16), date(2026,  3, 22), date(2026, 4, 20)],
        [9200, 8700, 11300, 9800, 10200, 9500, 10800],
    ):
        rows.append(txn(hdfc, amount=amt, type=TransactionType.debit,
                        tags=["groceries"], description="Groceries & household", date=d))

    # ── Utilities ─────────────────────────────────────────────────────────────
    for d, desc, amt in [
        (date(2025, 10, 10), "Electricity bill",  2100),
        (date(2025, 11, 10), "Electricity bill",  1950),
        (date(2025, 12, 10), "Electricity bill",  2400),
        (date(2026,  1, 10), "Electricity bill",  2250),
        (date(2026,  2, 10), "Electricity bill",  1800),
        (date(2026,  3, 10), "Electricity bill",  2050),
        (date(2026,  4, 10), "Electricity bill",  1900),
        (date(2025, 10, 12), "Internet & OTT",     999),
        (date(2025, 11, 12), "Internet & OTT",     999),
        (date(2025, 12, 12), "Internet & OTT",     999),
        (date(2026,  1, 12), "Internet & OTT",     999),
        (date(2026,  2, 12), "Internet & OTT",     999),
        (date(2026,  3, 12), "Internet & OTT",     999),
        (date(2026,  4, 12), "Internet & OTT",     999),
    ]:
        rows.append(txn(hdfc, amount=amt, type=TransactionType.debit,
                        tags=["utilities"], description=desc, date=d))

    # ── Dining & leisure ──────────────────────────────────────────────────────
    for d, desc, amt in [
        (date(2025, 10, 22), "Restaurant",         3200),
        (date(2025, 11,  8), "Weekend trip",       12500),
        (date(2025, 11, 25), "Restaurant",          2800),
        (date(2025, 12, 15), "Movies & dining",     2100),
        (date(2025, 12, 27), "New Year party",      6400),
        (date(2026,  1, 20), "Restaurant",          2600),
        (date(2026,  2, 14), "Valentines dinner",   4500),
        (date(2026,  3,  3), "Restaurant",          2200),
        (date(2026,  4,  6), "Weekend getaway",     9800),
        (date(2026,  4, 27), "Restaurant",          3100),
    ]:
        tag = "leisure" if any(w in desc.lower() for w in ("trip", "party", "getaway")) else "dining"
        rows.append(txn(icici, amount=amt, type=TransactionType.debit,
                        tags=[tag], description=desc, date=d))

    # ── SIP investments ───────────────────────────────────────────────────────
    sip_pub_ids = [uuid.uuid4() for _ in range(7)]
    for i, d in enumerate([date(2025, 10, 8), date(2025, 11, 8), date(2025, 12, 8),
                            date(2026,  1, 8), date(2026,  2, 8), date(2026,  3, 8), date(2026, 4, 8)]):
        rows.append(txn(
            hdfc,
            instrument_id=nifty_inst.id if nifty_inst else None,
            amount=10000, type=TransactionType.debit,
            tags=["investment"], description="SIP — Nifty Index Fund", date=d,
        ))
        rows[-1].public_id = sip_pub_ids[i]

    # ── Dividend income ───────────────────────────────────────────────────────
    for d, amt in [(date(2025, 11, 14), 1420), (date(2026, 2, 18), 1650)]:
        rows.append(txn(
            sbi,
            instrument_id=hdfcbank_inst.id if hdfcbank_inst else None,
            amount=amt, type=TransactionType.credit,
            tags=["dividend"], description="Dividend — HDFCBANK", date=d,
        ))

    # ── FD maturity ───────────────────────────────────────────────────────────
    rows.append(txn(
        sbi,
        amount=537500, type=TransactionType.credit,
        tags=["fd_maturity"],
        description="FD maturity — SBI 1Y (Principal ₹5,00,000 + interest ₹37,500)",
        date=date(2026, 3, 15),
    ))

    db.bulk_save_objects(rows)
    db.commit()
    _ok(f"Created {len(rows)} transactions for user1")


def _seed_user1_term_accounts(db, user, accounts):
    from app.models.term_account import TermAccount, TermAccountType

    if db.query(TermAccount).filter(TermAccount.user_id == user.id).count() > 0:
        _skip("Term accounts (user1) already exist — skipping")
        return

    hdfc, sbi, _ = accounts
    if not hdfc or not sbi:
        _err("Missing accounts for user1 term accounts — skipping")
        return

    from app.commands.fd import fd_open
    from app.commands.ppf import ppf_deposit

    # FD: ₹2,00,000 @ 7.5% for 365 days, opened via HDFC
    fd = TermAccount(
        user_id=user.id,
        parent_account_id=hdfc.id,
        type=TermAccountType.fd,
        account_number="HDFC/FD/2025/11234",
        amount=200000,
        open_date=date(2025, 6, 1),
        tenure_days=365,
        interest_rate=7.5,
        maturity_amount=None,
        balance=200000,
    )
    db.add(fd)
    db.flush()
    fd_open(db, fd, hdfc, 200000, date(2025, 6, 1), user.id)
    db.commit()
    db.refresh(fd)
    _ok(f"Created FD #{fd.id} ₹2,00,000 @ 7.5% — matures {fd.maturity_date} (₹{fd.maturity_amount:,.2f})")

    # PPF: opened from SBI salary account with two historical deposits
    ppf = TermAccount(
        user_id=user.id,
        parent_account_id=sbi.id,
        type=TermAccountType.ppf,
        account_number="SBI/PPF/2020/00456",
        amount=500000,
        open_date=date(2020, 4, 1),
        tenure_days=None,
        interest_rate=7.1,
        maturity_amount=0,
        balance=500000,
    )
    db.add(ppf)
    db.flush()
    db.commit()
    db.refresh(ppf)

    for deposit_amt, deposit_date in [(150000, date(2025, 4, 5)), (150000, date(2026, 4, 3))]:
        ppf_deposit(db, ppf, sbi, deposit_amt, deposit_date, user.id)
        db.commit()
        db.refresh(ppf)

    _ok(f"Created PPF #{ppf.id} — balance ₹{ppf.balance:,.0f}, matures {ppf.maturity_date}")


def _seed_user1_investments(db, user, platform_accounts, instruments):
    from app.models.investment import Investment, InvestmentType

    if db.query(Investment).filter(Investment.user_id == user.id).count() > 0:
        _skip("Investments (user1) already exist — skipping")
        return

    zerodha, groww = platform_accounts
    z_id = zerodha.id if zerodha else None
    g_id = groww.id if groww else None

    def iid(name): return instruments[name].id if name in instruments else None

    investments = [
        Investment(user_id=user.id, platform_account_id=z_id, instrument_id=iid("Reliance Industries"),
                   type=InvestmentType.stock, name="Reliance Industries",
                   amount_invested=140000, current_value=151300, purchase_date=date(2024, 6, 12),
                   quantity=50, avg_buy_price=2800),
        Investment(user_id=user.id, platform_account_id=z_id, instrument_id=iid("HDFC Bank"),
                   type=InvestmentType.stock, name="HDFC Bank",
                   amount_invested=160000, current_value=172000, purchase_date=date(2024, 9, 3),
                   quantity=100, avg_buy_price=1600),
        Investment(user_id=user.id, platform_account_id=z_id, instrument_id=iid("Infosys"),
                   type=InvestmentType.stock, name="Infosys",
                   amount_invested=95200, current_value=102600, purchase_date=date(2025, 1, 20),
                   quantity=56, avg_buy_price=1700),
        Investment(user_id=user.id, platform_account_id=g_id, instrument_id=iid("Nippon India Nifty 50 Index Fund"),
                   type=InvestmentType.mutual_fund, name="Nifty 50 Index Fund — Direct",
                   amount_invested=120000, current_value=136500, purchase_date=date(2024, 4, 8),
                   folio_number="GRW/2024/00123", units=500, nav_at_purchase=240.00),
        Investment(user_id=user.id, platform_account_id=g_id, instrument_id=iid("HDFC Flexi Cap Fund"),
                   type=InvestmentType.mutual_fund, name="HDFC Flexi Cap Fund — Direct",
                   amount_invested=80000, current_value=92400, purchase_date=date(2024, 7, 15),
                   folio_number="GRW/2024/00456", units=1000, nav_at_purchase=80.00),
        Investment(user_id=user.id, platform_account_id=None, instrument_id=None,
                   type=InvestmentType.fixed_deposit, name="SBI FD — 1 Year",
                   amount_invested=500000, current_value=537500, purchase_date=date(2025, 3, 15),
                   bank_name="State Bank of India", fd_number="SBI/FD/2025/00789",
                   interest_rate=7.5, tenure_months=12, maturity_date=date(2026, 3, 15),
                   maturity_amount=537500, compounding="quarterly"),
        Investment(user_id=user.id, platform_account_id=None, instrument_id=None,
                   type=InvestmentType.gold, name="Sovereign Gold Bond 2024-I",
                   amount_invested=62700, current_value=74800, purchase_date=date(2024, 2, 20),
                   gold_form="SGB", weight_grams=10.0, purity="24K"),
        Investment(user_id=user.id, platform_account_id=None, instrument_id=None,
                   type=InvestmentType.ppf, name="PPF — SBI Branch",
                   amount_invested=500000, current_value=612000, purchase_date=date(2018, 4, 1),
                   notes="15-year lock-in, matures April 2033. Annual contribution ₹1.5L."),
        Investment(user_id=user.id, platform_account_id=None, instrument_id=None,
                   type=InvestmentType.nps, name="NPS Tier I — Aggressive",
                   amount_invested=150000, current_value=178000, purchase_date=date(2021, 8, 10),
                   notes="PRAN: 110012345678. Equity 75% / Corporate 15% / Govt 10%."),
    ]
    db.bulk_save_objects(investments)
    db.commit()
    _ok(f"Created {len(investments)} investments for user1")


# ────────────────────────────────────────────────────────────────────────────
#  USER 2 — Ananya Kapoor
# ────────────────────────────────────────────────────────────────────────────

def _seed_user2(db):
    from app.services.auth_service import create_user, get_user_by_email
    user = get_user_by_email(db, USER2_EMAIL)
    if user:
        _skip(f"User {USER2_EMAIL} already exists (id={user.id})")
        return user
    user = create_user(db, email=USER2_EMAIL, first_name=USER2_FIRST,
                       last_name=USER2_LAST, password=USER2_PASSWORD)
    _ok(f"Created user  {USER2_EMAIL}  (id={user.id})")
    return user


def _seed_user2_accounts(db, user):
    from app.models.account import Account, AccountType

    existing = {a.nickname for a in db.query(Account).filter(Account.user_id == user.id).all()}
    created  = []

    specs = [
        ("AXIS",  "Axis Primary",    AccountType.savings,  410000.00),
        ("ICICI", "ICICI Business",  AccountType.current,   85000.00),
    ]

    for short_name, nickname, actype, balance in specs:
        if nickname in existing:
            _skip(f"Account '{nickname}' already exists")
            acct = db.query(Account).filter(
                Account.user_id == user.id, Account.nickname == nickname
            ).first()
            created.append(acct)
            continue
        bank = _get_bank(db, short_name)
        if not bank:
            created.append(None)
            continue
        acct = Account(user_id=user.id, bank_id=bank.id, nickname=nickname,
                       account_type=actype, balance=balance)
        db.add(acct)
        db.commit()
        db.refresh(acct)
        _ok(f"Created account '{nickname}'")
        created.append(acct)

    return created  # [axis, icici_biz]


def _seed_user2_platform_accounts(db, user):
    from app.models.platform_account import PlatformAccount

    existing = {pa.nickname for pa in db.query(PlatformAccount).filter(PlatformAccount.user_id == user.id).all()}
    created  = []

    specs = [
        ("ZERODHA", "Zerodha — Ananya",   "ZER-AK-00456"),
        ("COIN",    "Coin (Zerodha MF)",  "COIN-AK-00456"),
    ]

    for short_name, nickname, account_id in specs:
        if nickname in existing:
            _skip(f"Platform account '{nickname}' already exists")
            pa = db.query(PlatformAccount).filter(
                PlatformAccount.user_id == user.id, PlatformAccount.nickname == nickname
            ).first()
            created.append(pa)
            continue
        platform = _get_platform(db, short_name)
        if not platform:
            created.append(None)
            continue
        pa = PlatformAccount(user_id=user.id, platform_id=platform.id,
                             nickname=nickname, account_id=account_id)
        db.add(pa)
        db.commit()
        db.refresh(pa)
        _ok(f"Created platform account '{nickname}'")
        created.append(pa)

    return created  # [zerodha, coin]


def _seed_user2_follios(db, user, platform_accounts, instruments):
    from app.models.follio import Follio

    zerodha, coin = platform_accounts
    if db.query(Follio).filter(Follio.user_id == user.id).count() > 0:
        _skip("Follios (user2) already exist — skipping")
        return

    specs = [
        (coin,    "PPFCF-22334455",    "Parag Parikh Flexi Cap Fund"),
        (coin,    "AXISBLUE-99887766", "Axis Bluechip Fund"),
        (zerodha, "ZER-TCS-AK-01",    "TCS"),
        (zerodha, "ZER-ICICI-AK-01",  "ICICI Bank"),
    ]
    count = 0
    for pa, follio_id, inst_name in specs:
        if not pa or inst_name not in instruments:
            continue
        inst = instruments[inst_name]
        follio = Follio(
            follio_id=follio_id,
            user_id=user.id,
            platform_id=pa.platform_id,
            instrument_id=inst.id,
        )
        db.add(follio)
        count += 1
    db.commit()
    _ok(f"Created {count} follios for user2")


def _seed_user2_transactions(db, user, accounts, instruments):
    from app.models.transaction import LinkedAccountType, Transaction, TransactionType

    axis, icici_biz = accounts

    if db.query(Transaction).filter(Transaction.user_id == user.id).count() > 0:
        _skip("Transactions (user2) already exist — skipping")
        return

    ppf_inst = instruments.get("Parag Parikh Flexi Cap Fund")
    tcs_inst = instruments.get("TCS")
    rows = []

    def txn(acct=None, **kw):
        lat = LinkedAccountType.account if acct else None
        laid = acct.id if acct else None
        return Transaction(user_id=user.id, public_id=uuid.uuid4(),
                           linked_account_type=lat, linked_account_id=laid, **kw)

    # ── Freelance income (irregular) ──────────────────────────────────────────
    for d, amt, desc in [
        (date(2025, 10,  7), 120000, "Freelance project — Acme Corp"),
        (date(2025, 10, 22), 45000,  "Consulting retainer — Oct"),
        (date(2025, 11, 15), 180000, "Freelance project — DesignCo"),
        (date(2025, 12,  5), 45000,  "Consulting retainer — Nov"),
        (date(2025, 12, 20), 90000,  "Year-end bonus project"),
        (date(2026,  1, 12), 150000, "Freelance project — StartupX"),
        (date(2026,  2, 18), 45000,  "Consulting retainer — Feb"),
        (date(2026,  3,  8), 220000, "Large design contract"),
        (date(2026,  4,  5), 45000,  "Consulting retainer — Apr"),
        (date(2026,  4, 25), 95000,  "Freelance project — MediaCo"),
    ]:
        rows.append(txn(icici_biz, amount=amt, type=TransactionType.credit,
                        tags=["freelance"], description=desc, date=d))

    # ── Rent ──────────────────────────────────────────────────────────────────
    for d in [date(2025, 10, 1), date(2025, 11, 1), date(2025, 12, 1),
              date(2026,  1, 1), date(2026,  2, 1), date(2026,  3, 1), date(2026, 4, 1)]:
        rows.append(txn(axis, amount=32000, type=TransactionType.debit,
                        tags=["rent"], description="Studio rent — Koramangala", date=d))

    # ── Groceries & dining (Ananya eats out more) ────────────────────────────
    for d, amt, tag, desc in [
        (date(2025, 10, 10), 12000, "groceries", "Groceries — BigBasket"),
        (date(2025, 10, 19), 4800,  "dining",    "Team dinner"),
        (date(2025, 11,  8), 11500, "groceries", "Groceries"),
        (date(2025, 11, 21), 8200,  "dining",    "Client lunch & dinner"),
        (date(2025, 12,  9), 13400, "groceries", "Groceries — Dec"),
        (date(2025, 12, 24), 6500,  "dining",    "Christmas dinner"),
        (date(2026,  1, 12), 10800, "groceries", "Groceries — Jan"),
        (date(2026,  1, 26), 3200,  "dining",    "Republic Day brunch"),
        (date(2026,  2, 14), 7400,  "dining",    "Valentine's dinner"),
        (date(2026,  3,  7), 11200, "groceries", "Groceries — Mar"),
        (date(2026,  3, 20), 5100,  "dining",    "Holi celebrations"),
        (date(2026,  4, 10), 12600, "groceries", "Groceries — Apr"),
        (date(2026,  4, 23), 9800,  "leisure",   "Goa weekend trip"),
    ]:
        rows.append(txn(axis, amount=amt, type=TransactionType.debit,
                        tags=[tag], description=desc, date=d))

    # ── Utilities ─────────────────────────────────────────────────────────────
    for d, amt in [(date(2025, 10, 5), 1800), (date(2025, 11, 5), 1950), (date(2025, 12, 5), 2200),
                   (date(2026,  1, 5), 2050), (date(2026,  2, 5), 1700), (date(2026,  3, 5), 1900),
                   (date(2026,  4, 5), 1850)]:
        rows.append(txn(axis, amount=amt, type=TransactionType.debit,
                        tags=["utilities"], description="Electricity & internet", date=d))

    # ── SIP — Parag Parikh Flexi Cap ──────────────────────────────────────────
    for d in [date(2025, 10, 3), date(2025, 11, 3), date(2025, 12, 3),
              date(2026,  1, 3), date(2026,  2, 3), date(2026,  3, 3), date(2026, 4, 3)]:
        rows.append(txn(
            axis,
            instrument_id=ppf_inst.id if ppf_inst else None,
            amount=15000, type=TransactionType.debit,
            tags=["investment"], description="SIP — Parag Parikh Flexi Cap", date=d,
        ))

    # ── Stock purchase ────────────────────────────────────────────────────────
    rows.append(txn(
        icici_biz,
        instrument_id=tcs_inst.id if tcs_inst else None,
        amount=192000, type=TransactionType.debit,
        tags=["investment"], description="Stock buy — TCS 50 shares", date=date(2025, 12, 10),
    ))
    rows.append(txn(
        icici_biz,
        amount=85000, type=TransactionType.debit,
        tags=["investment"], description="Stock buy — ICICI Bank 50 shares", date=date(2026, 1, 22),
    ))

    db.bulk_save_objects(rows)
    db.commit()
    _ok(f"Created {len(rows)} transactions for user2")


def _seed_user2_term_accounts(db, user, accounts):
    from app.models.term_account import TermAccount, TermAccountType

    if db.query(TermAccount).filter(TermAccount.user_id == user.id).count() > 0:
        _skip("Term accounts (user2) already exist — skipping")
        return

    axis, icici_biz = accounts
    if not axis:
        _err("Missing Axis account for user2 term accounts — skipping")
        return

    from app.commands.fd import fd_open, fd_close
    from app.commands.ppf import ppf_deposit

    # Ensure accounts have enough balance to cover all FD openings
    axis.balance = float(axis.balance) + 700000
    icici_biz.balance = float(icici_biz.balance) + 400000
    db.commit()

    def _fd(parent, acct_num, amount, open_date, tenure_days, rate):
        ta = TermAccount(user_id=user.id, parent_account_id=parent.id,
                         type=TermAccountType.fd, account_number=acct_num,
                         amount=amount, open_date=open_date, tenure_days=tenure_days,
                         interest_rate=rate, maturity_amount=None, balance=amount)
        db.add(ta); db.flush()
        fd_open(db, ta, parent, amount, open_date, user.id)
        db.commit(); db.refresh(ta)
        return ta

    # Active FD 1: Axis ₹3,00,000 @ 7.75% 730d
    fd1 = _fd(axis, "AXIS/FD/2024/00321", 300000, date(2024, 8, 1), 730, 7.75)
    _ok(f"Created FD #{fd1.id} {fd1.account_number} — matures {fd1.maturity_date} (₹{fd1.maturity_amount:,.2f})")

    # Active FD 2: Axis ₹1,50,000 @ 7.25% 365d
    fd2 = _fd(axis, "AXIS/FD/2025/00501", 150000, date(2025, 1, 15), 365, 7.25)
    _ok(f"Created FD #{fd2.id} {fd2.account_number} — matures {fd2.maturity_date} (₹{fd2.maturity_amount:,.2f})")

    # Active FD 3: ICICI ₹2,00,000 @ 7.5% 180d
    fd3 = _fd(icici_biz, "ICICI/FD/2026/00102", 200000, date(2026, 2, 1), 180, 7.5)
    _ok(f"Created FD #{fd3.id} {fd3.account_number} — matures {fd3.maturity_date} (₹{fd3.maturity_amount:,.2f})")

    # Matured FD 1: Axis ₹1,00,000 @ 7.0% 365d — closed Jan 2024
    fd4 = _fd(axis, "AXIS/FD/2023/00188", 100000, date(2023, 1, 10), 365, 7.0)
    fd_close(db, fd4, axis, float(fd4.maturity_amount), date(2024, 1, 10), user.id)
    db.commit(); db.refresh(fd4)
    _ok(f"Created FD #{fd4.id} {fd4.account_number} — matured {fd4.closed_date} (₹{fd4.closed_amount:,.2f})")

    # Matured FD 2: ICICI ₹75,000 @ 6.8% 180d — closed Jun 2024
    fd5 = _fd(icici_biz, "ICICI/FD/2023/00445", 75000, date(2023, 12, 1), 180, 6.8)
    fd_close(db, fd5, icici_biz, float(fd5.maturity_amount), date(2024, 6, 1), user.id)
    db.commit(); db.refresh(fd5)
    _ok(f"Created FD #{fd5.id} {fd5.account_number} — matured {fd5.closed_date} (₹{fd5.closed_amount:,.2f})")

    # PPF: opened from Axis with two annual deposits
    ppf = TermAccount(user_id=user.id, parent_account_id=axis.id, type=TermAccountType.ppf,
                      account_number="AXIS/PPF/2022/00789", amount=100000,
                      open_date=date(2022, 4, 1), tenure_days=None,
                      interest_rate=7.1, maturity_amount=0, balance=100000)
    db.add(ppf); db.flush(); db.commit(); db.refresh(ppf)

    for deposit_amt, deposit_date in [(100000, date(2025, 4, 2)), (100000, date(2026, 4, 4))]:
        ppf_deposit(db, ppf, axis, deposit_amt, deposit_date, user.id)
        db.commit(); db.refresh(ppf)

    _ok(f"Created PPF #{ppf.id} {ppf.account_number} — balance ₹{ppf.balance:,.0f}, matures {ppf.maturity_date}")


def _seed_user2_investments(db, user, platform_accounts, instruments):
    from app.models.investment import Investment, InvestmentType

    if db.query(Investment).filter(Investment.user_id == user.id).count() > 0:
        _skip("Investments (user2) already exist — skipping")
        return

    zerodha, coin = platform_accounts
    z_id = zerodha.id if zerodha else None
    c_id = coin.id if coin else None

    def iid(name): return instruments[name].id if name in instruments else None

    investments = [
        Investment(user_id=user.id, platform_account_id=z_id, instrument_id=iid("TCS"),
                   type=InvestmentType.stock, name="TCS",
                   amount_invested=192000, current_value=218400, purchase_date=date(2025, 12, 10),
                   quantity=50, avg_buy_price=3840),
        Investment(user_id=user.id, platform_account_id=z_id, instrument_id=iid("ICICI Bank"),
                   type=InvestmentType.stock, name="ICICI Bank",
                   amount_invested=85000, current_value=92500, purchase_date=date(2026, 1, 22),
                   quantity=50, avg_buy_price=1700),
        Investment(user_id=user.id, platform_account_id=c_id, instrument_id=iid("Parag Parikh Flexi Cap Fund"),
                   type=InvestmentType.mutual_fund, name="Parag Parikh Flexi Cap — Direct",
                   amount_invested=105000, current_value=122800, purchase_date=date(2025, 10, 3),
                   folio_number="PPFCF-22334455", units=600, nav_at_purchase=175.00),
        Investment(user_id=user.id, platform_account_id=c_id, instrument_id=iid("Axis Bluechip Fund"),
                   type=InvestmentType.mutual_fund, name="Axis Bluechip Fund — Direct",
                   amount_invested=60000, current_value=67200, purchase_date=date(2025, 10, 15),
                   folio_number="AXISBLUE-99887766", units=800, nav_at_purchase=75.00),
        Investment(user_id=user.id, platform_account_id=None, instrument_id=None,
                   type=InvestmentType.fixed_deposit, name="Axis Bank FD — 2 Year",
                   amount_invested=200000, current_value=232000, purchase_date=date(2024, 8, 1),
                   bank_name="Axis Bank", fd_number="AXIS/FD/2024/00321",
                   interest_rate=7.75, tenure_months=24, maturity_date=date(2026, 8, 1),
                   maturity_amount=232000, compounding="quarterly"),
        Investment(user_id=user.id, platform_account_id=None, instrument_id=None,
                   type=InvestmentType.gold, name="Digital Gold — PhonePe",
                   amount_invested=25000, current_value=29400, purchase_date=date(2025, 3, 15),
                   gold_form="coin", weight_grams=5.5, purity="24K"),
        Investment(user_id=user.id, platform_account_id=None, instrument_id=None,
                   type=InvestmentType.nps, name="NPS Tier I — Moderate",
                   amount_invested=72000, current_value=84500, purchase_date=date(2023, 4, 1),
                   notes="PRAN: 110098765432. Equity 50% / Corporate 25% / Govt 25%."),
    ]
    db.bulk_save_objects(investments)
    db.commit()
    _ok(f"Created {len(investments)} investments for user2")


# ── Command ───────────────────────────────────────────────────────────────────

@app.command("data")
def seed_data(
    reset: bool = typer.Option(False, "--reset", help="Delete test users first, then reseed"),
):
    """Seed two test users with full accounts, transactions, follios, and investments."""
    from sqlalchemy import text

    from app.services.auth_service import get_user_by_email

    db = SessionLocal()
    try:
        if reset:
            for email in [USER1_EMAIL, USER2_EMAIL]:
                user = get_user_by_email(db, email)
                if user:
                    db.execute(text("DELETE FROM users WHERE id = :id"), {"id": user.id})
                    db.commit()
                    console.print(f"  [yellow]↺[/yellow] Deleted {email}")

        # ── User 1 ────────────────────────────────────────────────────────────
        console.rule("[bold green]User 1 — Prashant Sharma[/bold green]")
        user1 = _seed_user1(db)
        accts1 = _seed_user1_accounts(db, user1)
        pa1   = _seed_user1_platform_accounts(db, user1)
        inst1 = _resolve_instruments(db, user1, [
            "Reliance Industries", "HDFC Bank", "Infosys",
            "Nippon India Nifty 50 Index Fund", "HDFC Flexi Cap Fund",
        ])
        _seed_user1_follios(db, user1, pa1, inst1)
        _seed_user1_transactions(db, user1, accts1, inst1)
        _seed_user1_term_accounts(db, user1, accts1)
        _seed_user1_investments(db, user1, pa1, inst1)

        # ── User 2 ────────────────────────────────────────────────────────────
        console.rule("[bold cyan]User 2 — Ananya Kapoor[/bold cyan]")
        user2 = _seed_user2(db)
        accts2 = _seed_user2_accounts(db, user2)
        pa2   = _seed_user2_platform_accounts(db, user2)
        inst2 = _resolve_instruments(db, user2, [
            "TCS", "ICICI Bank",
            "Parag Parikh Flexi Cap Fund", "Axis Bluechip Fund",
        ])
        _seed_user2_follios(db, user2, pa2, inst2)
        _seed_user2_transactions(db, user2, accts2, inst2)
        _seed_user2_term_accounts(db, user2, accts2)
        _seed_user2_investments(db, user2, pa2, inst2)

        # ── Summary ───────────────────────────────────────────────────────────
        console.rule(style="bright_black")
        console.print(f"  [bold]User 1[/bold]  {USER1_EMAIL}  /  {USER1_PASSWORD}  (id={user1.id})")
        console.print(f"  [bold]User 2[/bold]  {USER2_EMAIL}  /  {USER2_PASSWORD}  (id={user2.id})")
        console.rule(style="bright_black")

    finally:
        db.close()
