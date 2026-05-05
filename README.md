# FinTrack 💰

> Take control of your finances — track every rupee, every account, every investment, in one place.

FinTrack is a self-hosted personal finance tracker built as a **single-origin monolith**: one FastAPI process serves both the REST API and the production-built React SPA. No cloud dependencies, no subscriptions — just your data, on your machine.

---

## What you can track

| Domain | Details |
|--------|---------|
| 🏦 **Bank Accounts** | Savings, current, salary, NRE/NRO — with full transaction history |
| 📈 **Investments** | Stocks, mutual funds, gold, crypto, NPS, real estate |
| 🔒 **Fixed Deposits** | Linked to parent accounts, auto-calculates maturity date & amount |
| 🌿 **PPF** | 15-year tenure, deposit tracking, balance driven by transactions |
| 📊 **Dashboard** | Net worth, spending trends, investment breakdown — Redis-cached for instant loads |
| 🧾 **Audit Log** | Every balance change is traceable back to the transaction that caused it |

---

## Tech Stack

**Backend** — Python 3.13 · FastAPI · SQLAlchemy 2 · Alembic · PostgreSQL · Redis · `uv`

**Frontend** — React 19 · TypeScript · Vite · TanStack Query · shadcn/ui · Recharts · Tailwind CSS v4

---

## Prerequisites

Make sure the following are installed before you begin:

- [pyenv](https://github.com/pyenv/pyenv) — Python version manager
- [nvm](https://github.com/nvm-sh/nvm) — Node version manager
- [uv](https://docs.astral.sh/uv/) — Python package manager (`pip install uv` or `brew install uv`)
- **PostgreSQL** running locally
- **Redis** running locally (optional — the app falls back to direct DB queries without it)

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/prashantomer/FinTrack.git
cd FinTrack
```

### 2. Set up runtimes

```bash
# Python 3.13.5
pyenv install 3.13.5

# Node 24 LTS (reads .nvmrc automatically)
source ~/.nvm/nvm.sh && nvm install
```

### 3. Set up the database

```bash
createdb fintrack_db
createuser fintrack_user --pwprompt
psql -c "GRANT ALL ON DATABASE fintrack_db TO fintrack_user;"
```

### 4. Configure the backend

```bash
cp backend/.env.example backend/.env   # if example exists, otherwise create it
```

Edit `backend/.env`:

```env
DATABASE_URL=postgresql+psycopg://fintrack_user:your_password@localhost:5432/fintrack_db
SECRET_KEY=your_32_byte_hex_secret        # generate: python -c "import secrets; print(secrets.token_hex(32))"
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080         # 7 days
ENVIRONMENT=development
REDIS_URL=redis://localhost:6379/0        # optional — remove to disable caching
```

### 5. Install backend dependencies & run migrations

```bash
cd backend
uv sync                        # installs all dependencies into .venv
uv run alembic upgrade head    # creates all tables
```

### 6. Seed reference data

Banks and investment platforms are admin-managed — seed them once:

```bash
uv run python -m app.cli banks seed       # seeds banks from seeds/banks.csv
uv run python -m app.cli platforms seed   # seeds 11 investment platforms
```

### 7. Create your user

There is no public registration. Users are created from the terminal only:

```bash
uv run python -m app.cli users create
# → prompts for email, full name, and password

# Or let it generate a random password for you:
uv run python -m app.cli users create --generate
```

### 8. Install frontend dependencies

```bash
cd ../frontend
source ~/.nvm/nvm.sh && nvm use   # ensure correct Node version
npm install
```

---

## Running in Development

You'll need two terminals:

**Terminal 1 — Backend** (hot-reload, API docs at `/docs`):
```bash
cd backend
uv run fastapi dev main.py
# → http://localhost:8000
```

**Terminal 2 — Frontend** (HMR, proxies `/api` → `:8000`):
```bash
cd frontend
npm run dev
# → http://localhost:5173
```

Open `http://localhost:5173` and log in with the credentials you created above.

---

## Running in Production

Build the frontend once, then serve everything from a single FastAPI process:

```bash
cd frontend && npm run build

cd ../backend
uv run fastapi run main.py --host 0.0.0.0 --port 8000 --workers 4
# → http://localhost:8000 serves both the API and the React SPA
```

---

## Project Structure

```
FinTrack/
├── backend/
│   ├── app/
│   │   ├── models/        # SQLAlchemy ORM models
│   │   ├── schemas/       # Pydantic v2 request/response schemas
│   │   ├── routers/       # Route handlers (thin — delegate to services)
│   │   ├── services/      # Business logic and DB queries
│   │   └── cli/           # Admin CLI commands (users, banks, transactions)
│   ├── alembic/           # Database migrations
│   ├── seeds/             # CSV seed files for reference data
│   └── tests/             # pytest suite
└── frontend/
    └── src/
        ├── api/           # Axios call functions per domain
        ├── components/    # UI components (shadcn/ui + custom)
        ├── hooks/         # TanStack Query hooks
        ├── pages/         # One file per route
        └── types/         # TypeScript interfaces matching backend schemas
```

---

## Useful Commands

```bash
# Run all backend tests
cd backend && uv run pytest

# Type-check the frontend
cd frontend && npx tsc --noEmit

# Generate a new DB migration
cd backend && uv run alembic revision --autogenerate -m "your description"

# Correct a transaction (admin CLI)
cd backend && uv run python -m app.cli transactions correct <id>

# Deactivate a transaction and reverse its balance impact
cd backend && uv run python -m app.cli transactions deactivate <id>
```

---

## License

MIT — see [LICENSE](LICENSE).
