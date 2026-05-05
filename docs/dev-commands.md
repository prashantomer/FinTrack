# FinTrack — Dev Commands Reference

Useful commands for running, testing, and exploring the app. Auto-appended by the Claude Code PostToolUse Bash hook for new commands run during development.

---

## Running the App

### Backend dev server (hot-reload)

```bash
cd backend
uv run fastapi dev main.py
# API docs: http://localhost:8000/docs
# Redoc:    http://localhost:8000/redoc
```

### Frontend dev server (HMR, proxies /api → :8000)

```bash
source ~/.nvm/nvm.sh && nvm use   # ensure Node 24
cd frontend
npm run dev
# App: http://localhost:5173
```

### Run both together (two terminals)

```bash
# Terminal 1
cd backend && uv run fastapi dev main.py

# Terminal 2
source ~/.nvm/nvm.sh && nvm use && cd frontend && npm run dev
```

### Production monolith (single origin)

```bash
cd frontend && npm run build
cd backend && uv run fastapi run main.py --host 0.0.0.0 --port 8000 --workers 4
# Serves API + SPA at http://localhost:8000
```

---

## Database Migrations

```bash
cd backend

# Auto-generate a migration after model changes
uv run alembic revision --autogenerate -m "add investment type"

# Apply all pending migrations
uv run alembic upgrade head

# Roll back one migration
uv run alembic downgrade -1

# View migration history
uv run alembic history --verbose
```

---

## Tests

```bash
cd backend

# Run all tests
uv run pytest

# Run with verbose output
uv run pytest -v

# Run a single file
uv run pytest tests/test_auth.py -v

# Run a single test by name
uv run pytest tests/test_auth.py::test_login_success -v

# Stop on first failure
uv run pytest -x
```

---

## Admin CLI

```bash
cd backend

# Create a user (interactive prompt)
uv run python -m app.cli users create

# Create a user with an auto-generated password
uv run python -m app.cli users create --generate

# Seed banks and investment platforms (run once)
uv run python -m app.cli banks seed
uv run python -m app.cli platforms seed

# List / inspect reference data
uv run python -m app.cli banks list
uv run python -m app.cli platforms list

# See all available CLI commands
uv run python -m app.cli --help
```

---

## Interactive Backend Console

Launch a Python REPL with the full app context loaded — useful for querying the DB, testing services, or inspecting models without hitting the API.

```bash
cd backend
uv run python
```

### Bootstrap the session

```python
# Paste this block to get a working DB session and imports
from app.database import SessionLocal
from app import models  # ensures all ORM models are registered
db = SessionLocal()

# Convenience aliases
from app.models.user import User
from app.models.transaction import Transaction
from app.models.investment import Investment
from app.models.account import Account
from app.models.bank import Bank
from app.models.platform import Platform
from app.models.platform_account import PlatformAccount
from app.models.instrument import Instrument
```

### Proxy shorthands

The console pre-loads lowercase plural proxy objects for every model. These are the fastest way to query.

```python
# ── Basic ─────────────────────────────────────────────────────────────────────
users.all                                        # all users as a rich table
users.first                                      # first row
users.count                                      # integer count
users.find(1)                                    # row with id=1

# ── Filtering ─────────────────────────────────────────────────────────────────
users.where(is_active=True).all
users.where(is_active=False).count
transactions.where(user_id=1).all
investments.where(user_id=1, type="mutual_fund").all

# ── Sorting & limiting ────────────────────────────────────────────────────────
banks.order_by("name").all
transactions.where(user_id=1).order_by("date", desc=True).all
transactions.where(user_id=1).order_by("date", desc=True).limit(10).all
investments.where(user_id=1).order_by("purchase_date", desc=True).limit(5).all

# ── Available proxies ────────────────────────────────────────────────────────
# users  banks  accounts  platforms  platform_accounts
# instruments  investments  transactions
```

### Pretty-printing results (manual)

```python
# table() is also available directly for custom queries
table(db.query(User).all())
table(db.query(Transaction).filter(Transaction.user_id == 1).order_by(Transaction.date.desc()).limit(20).all())
table(db.query(Investment).filter(Investment.user_id == 1).all())
```

### Example queries

```python
# ── Users ────────────────────────────────────────────────────────────────────

# List all users
users = db.query(User).all()
for u in users:
    print(u.id, u.email, u.full_name, u.is_active)

# Get a user by email
user = db.query(User).filter(User.email == "you@example.com").first()
print(user.id, user.full_name)

# Check if a user exists
exists = db.query(User).filter(User.email == "you@example.com").count() > 0

# ── Accounts ─────────────────────────────────────────────────────────────────

# List a user's bank accounts with bank name
accounts = (
    db.query(Account)
    .join(Bank, Account.bank_id == Bank.id)
    .filter(Account.user_id == user.id)
    .all()
)
for a in accounts:
    print(a.id, a.nickname, a.bank.name, a.account_type)

# ── Transactions ──────────────────────────────────────────────────────────────

from app.models.transaction import TransactionType

# List 10 most recent transactions for a user
txns = (
    db.query(Transaction)
    .filter(Transaction.user_id == user.id)
    .order_by(Transaction.date.desc())
    .limit(10)
    .all()
)
for t in txns:
    print(t.date, t.type, t.amount, t.description)

# Filter to outbound only
outbound = (
    db.query(Transaction)
    .filter(Transaction.user_id == user.id, Transaction.type == TransactionType.outbound)
    .order_by(Transaction.date.desc())
    .all()
)

# Sum of inbound vs outbound
from sqlalchemy import func
inbound_total = (
    db.query(func.sum(Transaction.amount))
    .filter(Transaction.user_id == user.id, Transaction.type == TransactionType.inbound)
    .scalar() or 0
)
outbound_total = (
    db.query(func.sum(Transaction.amount))
    .filter(Transaction.user_id == user.id, Transaction.type == TransactionType.outbound)
    .scalar() or 0
)
print(f"In: {inbound_total}  Out: {outbound_total}  Net: {inbound_total - outbound_total}")

# Transactions in a date range
from datetime import date
txns = (
    db.query(Transaction)
    .filter(
        Transaction.user_id == user.id,
        Transaction.date >= date(2025, 1, 1),
        Transaction.date <= date(2025, 12, 31),
    )
    .order_by(Transaction.date)
    .all()
)

# ── Investments ───────────────────────────────────────────────────────────────

from app.models.investment import InvestmentType

# List all investments for a user
investments = (
    db.query(Investment)
    .filter(Investment.user_id == user.id)
    .order_by(Investment.purchase_date.desc())
    .all()
)
for inv in investments:
    print(inv.type, inv.name, inv.amount_invested, inv.current_value)

# Filter to a specific type (e.g. mutual funds)
mfs = (
    db.query(Investment)
    .filter(Investment.user_id == user.id, Investment.type == InvestmentType.mutual_fund)
    .all()
)

# Group investments by type with total invested
rows = (
    db.query(Investment.type, func.count(Investment.id).label("n"), func.sum(Investment.amount_invested).label("total"))
    .filter(Investment.user_id == user.id)
    .group_by(Investment.type)
    .all()
)
for type_, n, total in rows:
    print(f"{type_:15s}  count={n}  invested={total}")

# Total current portfolio value
total_value = (
    db.query(func.sum(Investment.current_value))
    .filter(Investment.user_id == user.id)
    .scalar() or 0
)
print(f"Portfolio value: {total_value}")

# Unrealised P&L per investment
for inv in investments:
    if inv.current_value is not None:
        pnl = float(inv.current_value) - float(inv.amount_invested)
        pct = pnl / float(inv.amount_invested) * 100
        print(f"{inv.name:30s}  P&L={pnl:+.2f}  ({pct:+.1f}%)")

# ── Instruments ───────────────────────────────────────────────────────────────

# Search instruments by name
results = db.query(Instrument).filter(Instrument.name.ilike("%nifty%")).all()
for i in results:
    print(i.id, i.name, i.type, i.ticker_symbol)

# List instruments tracked by a user
from app.models.instrument import user_instruments
tracked = (
    db.query(Instrument)
    .join(user_instruments, Instrument.id == user_instruments.c.instrument_id)
    .filter(user_instruments.c.user_id == user.id)
    .order_by(Instrument.name)
    .all()
)
for i in tracked:
    print(i.id, i.name, i.ticker_symbol)

# ── Banks & Platforms ─────────────────────────────────────────────────────────

# List all banks
banks = db.query(Bank).order_by(Bank.name).all()
for b in banks:
    print(b.id, b.short_name, b.name)

# List all platforms
platforms = db.query(Platform).order_by(Platform.name).all()
for p in platforms:
    print(p.id, p.short_name, p.type)

# ── Services (bypass HTTP) ────────────────────────────────────────────────────

# Call service functions directly — same logic as the API, no HTTP overhead
from app.services.transaction_service import get_transactions
from app.services.investment_service import get_investments
from app.services.report_service import get_dashboard

txns, total = get_transactions(db, user_id=user.id, skip=0, limit=10)
investments = get_investments(db, user_id=user.id)
dashboard = get_dashboard(db, user_id=user.id)
print(dashboard)

# ── Quick mutations ───────────────────────────────────────────────────────────

# Fix a transaction amount (e.g. data correction)
txn = db.query(Transaction).filter(Transaction.id == 42).first()
txn.amount = 1500.00
db.commit()
db.refresh(txn)
print("Updated:", txn.amount)

# Soft-deactivate a user
u = db.query(User).filter(User.email == "test@example.com").first()
u.is_active = False
db.commit()
```

### Joins

```python
# ── Transactions with account + bank name ────────────────────────────────────
rows = (
    db.query(Transaction, Account, Bank)
    .join(Account, Transaction.account_id == Account.id)
    .join(Bank, Account.bank_id == Bank.id)
    .filter(Transaction.user_id == 1)
    .order_by(Transaction.date.desc())
    .limit(20)
    .all()
)
for txn, acc, bank in rows:
    print(txn.date, bank.short_name, acc.nickname, txn.type, txn.amount, txn.description)

# ── Investments with platform account + platform name ────────────────────────
rows = (
    db.query(Investment, PlatformAccount, Platform)
    .join(PlatformAccount, Investment.platform_account_id == PlatformAccount.id)
    .join(Platform, PlatformAccount.platform_id == Platform.id)
    .filter(Investment.user_id == 1)
    .all()
)
for inv, pa, plat in rows:
    print(plat.short_name, pa.nickname, inv.type, inv.name, inv.amount_invested)

# ── Investments with linked instrument ticker ─────────────────────────────────
rows = (
    db.query(Investment, Instrument)
    .join(Instrument, Investment.instrument_id == Instrument.id)
    .filter(Investment.user_id == 1)
    .all()
)
for inv, inst in rows:
    print(inv.name, inst.ticker_symbol, inst.exchange, inv.amount_invested)

# ── Left outer join (include investments with no instrument linked) ────────────
from sqlalchemy import outerjoin
rows = (
    db.query(Investment, Instrument)
    .outerjoin(Instrument, Investment.instrument_id == Instrument.id)
    .filter(Investment.user_id == 1)
    .all()
)
for inv, inst in rows:
    ticker = inst.ticker_symbol if inst else "—"
    print(inv.name, ticker, inv.amount_invested)

# ── Transactions with instrument name (optional link) ────────────────────────
rows = (
    db.query(Transaction, Instrument)
    .outerjoin(Instrument, Transaction.instrument_id == Instrument.id)
    .filter(Transaction.user_id == 1)
    .all()
)
for txn, inst in rows:
    print(txn.date, txn.amount, inst.name if inst else "—")

# ── Instruments tracked by a user (many-to-many via user_instruments) ─────────
from app.models.instrument import user_instruments
tracked = (
    db.query(Instrument)
    .join(user_instruments, Instrument.id == user_instruments.c.instrument_id)
    .filter(user_instruments.c.user_id == 1)
    .order_by(Instrument.name)
    .all()
)
table(tracked)

# ── User with their account count ────────────────────────────────────────────
from sqlalchemy import func
rows = (
    db.query(User, func.count(Account.id).label("account_count"))
    .outerjoin(Account, User.id == Account.user_id)
    .group_by(User.id)
    .all()
)
for user, count in rows:
    print(user.email, count)

# ── Spending by bank (sum outbound transactions grouped by bank) ──────────────
rows = (
    db.query(Bank.name, func.sum(Transaction.amount).label("total"))
    .join(Account, Bank.id == Account.bank_id)
    .join(Transaction, Account.id == Transaction.account_id)
    .filter(Transaction.user_id == 1, Transaction.type == "outbound")
    .group_by(Bank.name)
    .order_by(func.sum(Transaction.amount).desc())
    .all()
)
for bank_name, total in rows:
    print(f"{bank_name:30s}  ₹{total:,.2f}")

# ── Investment value by platform ──────────────────────────────────────────────
rows = (
    db.query(Platform.name, func.sum(Investment.current_value).label("value"))
    .join(PlatformAccount, Platform.id == PlatformAccount.platform_id)
    .join(Investment, PlatformAccount.id == Investment.platform_account_id)
    .filter(Investment.user_id == 1)
    .group_by(Platform.name)
    .order_by(func.sum(Investment.current_value).desc())
    .all()
)
for plat_name, value in rows:
    print(f"{plat_name:30s}  ₹{value:,.2f}")
```

### Cleanup

```python
# Always close the session when done
db.close()
```

---

## Frontend Type-check & Lint

```bash
cd frontend

# TypeScript type check (no emit)
npx tsc --noEmit

# ESLint
npm run lint

# Production build (outputs to frontend/dist/)
npm run build
```

---

## One-time Setup

```bash
# PostgreSQL database
createdb fintrack_db
createuser fintrack_user --pwprompt
psql -c "GRANT ALL ON DATABASE fintrack_db TO fintrack_user;"

# Python runtime
pyenv install 3.13.5

# Node runtime
source ~/.nvm/nvm.sh && nvm install   # reads .nvmrc (Node 24)
```

### 2026-05-03 10:54:23
**Extract file path from tool_input**

```bash
echo "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/dev-commands.md"
```

### 2026-05-03 11:28:45
**Find the backend architecture documentation file**

```bash
find /Users/prashanto/Documents/Personal/Learnings/FinTrack -name "backend-architecture.md" -type f 2>/dev/null
```

### 2026-05-03 12:20:38
**Check size of architecture doc**

```bash
wc -l /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 12:20:55
**Check if _seed_instruments function exists**

```bash
grep -n "def _seed_instruments" app/cli/seed.py
```

### 2026-05-03 12:25:09
```bash
tail -500 /Users/prashanto/.claude/projects/-Users-prashanto-Documents-Personal-Learnings-FinTrack/77e64f4e-5680-4a24-88f4-ea750ccb7fd3.jsonl | jq -r '.user_message // empty' | head -20
```

### 2026-05-03 12:30:11
```bash
test -f "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md" && echo "File exists" || echo "File not found"
```

### 2026-05-03 13:40:56
**Check if architecture doc exists**

```bash
test -f "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md" && echo "exists" || echo "not found"
```

### 2026-05-03 13:41:08
**Search for Follio mentions in architecture doc**

```bash
grep -i "follio" "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md" | head -20
```

### 2026-05-03 13:41:16
**Check for Follio model file**

```bash
ls -la "/Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/" | grep -i follio
```

### 2026-05-03 13:41:20
**Count lines in Follio model**

```bash
wc -l "/Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/follio.py"
```

### 2026-05-03 13:45:22
```bash
find /Users/prashanto/Documents/Personal/Learnings/FinTrack -name "backend-architecture.md" -type f
```

### 2026-05-03 13:47:15
**Get file line count**

```bash
cat /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md | wc -l
```

### 2026-05-03 13:49:33
**Apply migration**

```bash
uv run alembic upgrade head 2>&1
```

### 2026-05-03 13:51:26
**Apply migration in foreground**

```bash
uv run alembic upgrade head 2>&1
```

### 2026-05-03 14:00:29
```bash
wc -l "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/frontend-architecture.md"
```

### 2026-05-03 14:01:19
**Verify backend imports from correct directory**

```bash
cd /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend && uv run python -c "from app.main import app; print('Backend imports OK')" 2>&1
```

### 2026-05-03 14:01:29
**TypeScript errors**

```bash
cd /Users/prashanto/Documents/Personal/Learnings/FinTrack/frontend && source ~/.nvm/nvm.sh && nvm use --silent && npx tsc --noEmit 2>&1 | head -60
```

### 2026-05-03 17:08:35
**Find rework.txt file**

```bash
find /Users/prashanto/Documents/Personal/Learnings/FinTrack -name "rework.txt" 2>/dev/null
```

### 2026-05-03 17:15:31
**Create newplan directory**

```bash
mkdir -p /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/newplan
```

### 2026-05-03 17:48:25
```bash
cat /Users/prashanto/.claude/projects/-Users-prashanto-Documents-Personal-Learnings-FinTrack/77e64f4e-5680-4a24-88f4-ea750ccb7fd3.jsonl | head -1
```

### 2026-05-03 18:04:02
**Create seeds directory**

```bash
mkdir -p /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/seeds
```

### 2026-05-03 18:05:58
```bash
find /Users/prashanto/Documents/Personal/Learnings/FinTrack -name "backend-architecture.md" -o -name "architecture.md" 2>/dev/null
```

### 2026-05-03 18:10:13
**Check if backend-architecture.md exists**

```bash
test -f "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md" && echo "File exists" || echo "File does not exist"
```

### 2026-05-03 18:13:18
**Generate new Alembic revision**

```bash
uv run alembic revision -m "seed_banks_from_csv"
```

### 2026-05-03 18:16:47
```bash
wc -l /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 18:17:40
**Check if backend-architecture.md exists**

```bash
test -f /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md && echo "File exists" || echo "File does not exist"
```

### 2026-05-03 18:17:55
**Find the line number for Database Migrations section**

```bash
grep -n "2.11 Database Migrations" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 18:35:41
**Find line number of database schema section**

```bash
grep -n "2.2 Database Schema" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 18:35:46
**Check if term_accounts is mentioned in the schema**

```bash
sed -n '272,500p' /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md | grep -A 5 "tables"
```

### 2026-05-03 18:36:55
```bash
grep -n "TermAccount" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 18:38:39
```bash
grep -n "2.2 Database Schema" "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md" | head -1
```

### 2026-05-03 18:38:43
```bash
grep -n "2.11 Database Migrations" "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md"
```

### 2026-05-03 18:41:07
```bash
ls -la /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/ 2>/dev/null | grep -i term || echo "No term_account.py found"
```

### 2026-05-03 18:42:05
```bash
find /Users/prashanto/Documents/Personal/Learnings/FinTrack -name "*backend-architecture*" -type f
```

### 2026-05-03 18:42:28
```bash
grep -n "class TransactionType" /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/transaction.py
```

### 2026-05-03 18:43:24
```bash
grep -n -i "term" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md | head -20
```

### 2026-05-03 18:43:33
```bash
find /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/routers -name "*term*" -type f 2>/dev/null
```

### 2026-05-03 18:43:35
```bash
ls -la /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/routers/ | grep -i term
```

### 2026-05-03 18:45:47
```bash
grep -n "### 2.3 API Contract" "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md" | head -1
```

### 2026-05-03 18:46:21
```bash
git diff app/routers/banks.py 2>/dev/null | head -100
```

### 2026-05-03 18:46:23
```bash
grep -n "def close_account" /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/services/bank_service.py 2>/dev/null | head -5
```

### 2026-05-03 18:46:25
```bash
grep -n "class AccountClose" /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/schemas/bank.py 2>/dev/null
```

### 2026-05-03 18:46:28
```bash
grep -A 10 "def.*close" /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/routers/banks.py
```

### 2026-05-03 18:46:53
```bash
grep -n "### 2.3 API Contract" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md | head -1
```

### 2026-05-03 18:47:42
```bash
ls -la /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/routers/ | grep -i term
```

### 2026-05-03 18:47:44
```bash
ls -la /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/ | grep -i term
```

### 2026-05-03 18:47:46
```bash
ls -la /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/schemas/ | grep -i term
```

### 2026-05-03 18:49:26
**Verify FastAPI app starts without errors**

```bash
uv run python -c "from app.main import create_app; app = create_app(); print('OK — routes:', len(app.routes))"
```

### 2026-05-03 18:53:47
```bash
wc -l /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 18:58:02
```bash
grep -n "### 2.5" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/frontend-architecture.md | head -1
```

### 2026-05-03 19:26:05
**Run TypeScript type check**

```bash
npx tsc --noEmit 2>&1
```

### 2026-05-03 21:09:07
```bash
grep -n "class TransactionCategory" "/Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/transaction.py"
```

### 2026-05-03 21:09:08
```bash
grep -n "TransactionCategory" "/Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/transaction.py" | head -10
```

### 2026-05-03 21:09:17
```bash
grep -n "LinkedAccountType" "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md"
```

### 2026-05-03 21:09:49
```bash
grep -n "LinkedAccountType" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 21:10:08
```bash
grep -n "TransactionCategory" /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/transaction.py
```

### 2026-05-03 21:12:41
**Verify app imports cleanly**

```bash
cd /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend && uv run python -c "from app.main import create_app; print('OK')" 2>&1
```

### 2026-05-03 21:12:45
**Verify CLI modules import cleanly**

```bash
uv run python -c "from app.cli.seed import app; from app.cli.console import app as c; print('OK')" 2>&1
```

### 2026-05-03 21:18:20
**Verify IPython import works**

```bash
uv run python -c "from IPython import start_ipython; print('OK')"
```

### 2026-05-03 22:06:56
```bash
grep -n "DELETE.*investment" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md | head -20
```

### 2026-05-03 22:07:42
**Search for Follios API endpoint section**

```bash
grep -n -A 10 "## Follios" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 22:07:44
**Search for any mention of follios**

```bash
grep -n -i "follio" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md
```

### 2026-05-03 22:08:30
**Verify app starts cleanly**

```bash
uv run python -c "from app.main import create_app; print('OK')" 2>/dev/null
```

### 2026-05-03 22:39:05
**TypeScript check**

```bash
cd /Users/prashanto/Documents/Personal/Learnings/FinTrack/frontend && npx tsc --noEmit 2>&1
```

### 2026-05-03 22:42:42
**Find stale transactions relationship in Account model**

```bash
grep -n "transactions" /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/models/bank.py
```

### 2026-05-03 22:44:13
**Verify app loads without relationship errors**

```bash
cd /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend && uv run python -c "from app.main import create_app; print('OK')" 2>/dev/null
```

### 2026-05-03 23:15:04
```bash
wc -l "/Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md"
```

### 2026-05-04 10:56:16
```bash
grep -n "2.2 Database Schema" /Users/prashanto/Documents/Personal/Learnings/FinTrack/docs/backend-architecture.md | head -5
```

### 2026-05-04 10:57:30
```bash
ls -la /Users/prashanto/Documents/Personal/Learnings/FinTrack/backend/app/routers/ | grep account
```

### 2026-05-04 10:58:43
```bash
find /Users/prashanto/Documents/Personal/Learnings/FinTrack -name "backend-architecture.md" -o -name "backend*architecture*" -type f
```
