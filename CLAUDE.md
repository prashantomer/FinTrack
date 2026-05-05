# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FinTrack is a personal finance tracker built as a **monolith**: a single FastAPI process that serves both the REST API (`/api/v1/`) and the production-built React SPA. In development, Vite's dev server (port 5173) proxies `/api` calls to FastAPI (port 8000).

## Runtime Versions (managed via version managers)

| Runtime | Version | Manager | Pin file |
|---------|---------|---------|----------|
| Python | 3.13.5 | pyenv | `.python-version` |
| Node.js | 24.15.0 LTS (Krypton) | nvm | `.nvmrc` |
| npm | 11.12.1 | bundled with Node | — |

```bash
# First-time setup: activate the correct runtimes
pyenv install 3.13.5       # if not already installed
source ~/.nvm/nvm.sh && nvm install  # reads .nvmrc automatically
```

## Common Commands

### One-time database setup

```bash
# Requires PostgreSQL running locally
createdb fintrack_db
createuser fintrack_user --pwprompt
psql -c "GRANT ALL ON DATABASE fintrack_db TO fintrack_user;"
```

### Creating a user

There is no public registration endpoint. Users are created from the terminal only:

```bash
cd backend

# Interactive — prompts for email, full name, and password
uv run python -m app.cli users create

# Auto-generate a random password (printed on success)
uv run python -m app.cli users create --generate
```

The CLI is grouped by domain:
```bash
uv run python -m app.cli --help
```

### Seeding banks and platforms

Banks and platforms are admin-managed from the CLI only — there is no UI to create them.

```bash
cd backend

# Seed banks from seeds/banks.csv (upsert by short_name, safe to re-run)
uv run python -m app.cli banks seed

# Seed 11 investment platforms (run once)
uv run python -m app.cli platforms seed

# List / add custom entries
uv run python -m app.cli banks list
uv run python -m app.cli banks create
uv run python -m app.cli platforms list
uv run python -m app.cli platforms create
```

### Backend

```bash
# Run dev server (hot-reload, docs at /docs)
cd backend && uv run fastapi dev main.py

# Run all tests
cd backend && uv run pytest

# Run a single test file / by name
cd backend && uv run pytest tests/test_auth.py -v
cd backend && uv run pytest tests/test_auth.py::test_register -v

# Database migrations (datetime-stamped revision IDs — see alembic.ini)
cd backend && uv run alembic revision --autogenerate -m "description"
cd backend && uv run alembic upgrade head
# No downgrade migrations — new migration required for any change
```

### Transaction admin (CLI only — no API)

```bash
cd backend

# Correct a transaction amount/type and recalculate account balance
uv run python -m app.cli transactions correct <id>

# Deactivate a transaction and reverse its balance impact
uv run python -m app.cli transactions deactivate <id>
```

### Frontend

```bash
# Ensure correct Node version
source ~/.nvm/nvm.sh && nvm use

# Dev server with HMR (proxies /api → localhost:8000)
cd frontend && npm run dev

# Production build (outputs to frontend/dist/)
cd frontend && npm run build

# Type checking
cd frontend && npx tsc --noEmit

# Lint
cd frontend && npm run lint

# Add a shadcn/ui component
cd frontend && npx shadcn@latest add <component-name>
```

### Production (monolith)

```bash
cd frontend && npm run build
cd backend && uv run fastapi run main.py --host 0.0.0.0 --port 8000 --workers 4
# Single origin at http://localhost:8000 serves both API and SPA
```

## Architecture

### Backend (`backend/`)

**Stack**: FastAPI 0.136 + SQLAlchemy 2.0 + Alembic + PostgreSQL via `psycopg[binary]` (psycopg3)

```
backend/
├── app/
│   ├── main.py            # FastAPI factory, router registration, SPA static serving
│   ├── config.py          # pydantic-settings; reads backend/.env
│   ├── database.py        # SQLAlchemy engine, SessionLocal, Base
│   ├── dependencies.py    # get_db(), get_current_user() (shared FastAPI deps)
│   ├── models/            # SQLAlchemy ORM models
│   ├── schemas/           # Pydantic v2 request/response schemas
│   ├── routers/           # Route handlers (thin; delegate to services)
│   ├── services/          # Business logic and DB queries
│   └── utils/             # Shared helpers (pagination, etc.)
├── alembic/               # Migrations; env.py must import all models
├── seeds/                 # CSV seed files (banks.csv, platforms.csv)
└── tests/                 # pytest; uses httpx AsyncClient via conftest.py
```

**Auth**: JWT (HS256, 7-day expiry) via `python-jose`. Passwords hashed with `passlib[bcrypt]`. `get_current_user` dependency in `dependencies.py` validates the Bearer token on protected routes.

**Transaction model** (see `models/transaction.py`):
- `type`: `credit` | `debit` (PostgreSQL enum `transaction_type`)
- `linked_account_type` + `linked_account_id`: polymorphic FK — no DB-level FK; resolved in service layer. `linked_account_type` is `account` (→ `accounts.id`) or `term_account` (→ `term_accounts.id`)
- `tags`: `ARRAY(Text)`, nullable — free-form labels replacing the old `category` enum
- `bank_ref`: `String(100)`, nullable — user-entered UTR/IMPS reference for credit transactions
- `is_active`: `Boolean` — soft-delete; CLI `deactivate` sets this and reverses balance
- Transactions are **immutable from the API** — no `PUT` or `DELETE` endpoints. Use CLI `transactions correct` / `deactivate` for admin corrections.

**Balance hooks** (`services/transaction_service.py → _apply_balance_delta`):
- `create_transaction` auto-updates the linked account balance after flush
- `credit` → `+amount`, `debit` → `-amount`
- FD `term_account` links are **skipped** (FD balance tracks principal, not running balance)
- CLI `correct` / `deactivate` reverses old delta and applies new
- Seed data uses `bulk_save_objects` which **bypasses** service hooks — balances are not auto-updated in seed

**Term accounts** (`models/term_account.py`, `services/term_account_service.py`):
- STI table `term_accounts` with `type`: `fd` | `ppf`
- FD creation: validates sufficient balance on parent savings account, creates paired savings-debit + FD-credit transactions (only savings balance updated)
- PPF creation: no paired transactions on create; both balances update on PPF investment transactions
- `maturity_date` / `maturity_amount`: auto-calculated on create (stored, not recomputed)
- FD `maturity_amount` = `amount * (1 + rate/100 * tenure_days/365)`
- PPF `maturity_date` = `open_date + 15 years`; `maturity_amount` is user-provided

**Account closure** (`services/bank_service.py → close_account`): sets `closed_date` + `closed_amount` on `accounts` table. Term account closure (`close_term_account`) credits `closed_amount` back to parent savings account.

**Investment model** uses **single-table inheritance** — one `investments` table with nullable type-specific columns. The `type` enum discriminates rows: `stock`, `mutual_fund`, `fixed_deposit`, `gold`, `crypto`, `ppf`, `nps`, `real_estate`.

**Reference data** (admin-only, CLI-managed):
- `banks` + `accounts` — global bank list; users create their own `accounts` via API. `Bank.short_name` is max 6 chars, unique, used as a display code.
- `platforms` + `platform_accounts` — global investment platform list; users create `platform_accounts`.
- `instruments` — global catalogue of investable securities. Both transactions and investments can link to `instrument_id`.

**`app/models/__init__.py`** imports all models — ensures mapper registry is fully populated before string-referenced relationships are resolved.

**Database connection string**: `postgresql+psycopg://` (psycopg3 dialect, not `postgresql://`).

**Migrations**: Alembic revision IDs are datetime-stamped (`YYYYMMDDHHmmSS`) via a `process_revision_directives` hook in `alembic/env.py`. No downgrade migrations — new migration for every change. Sleep ≥2s between generating multiple migrations to avoid collisions.

### Frontend (`frontend/`)

**Stack**: React 19 + TypeScript 6 + Vite 8 + React Router v7 + TanStack Query v5 + react-hook-form + Zod v4 + Recharts 3 + shadcn/ui + Tailwind CSS v4

```
frontend/src/
├── api/           # Axios call functions per domain (not hooks — just fetch logic)
│   ├── banks.ts        # listBanks, listAccounts, createAccount, updateAccount, closeAccount, deleteAccount
│   ├── term_accounts.ts # listTermAccounts, createTermAccount, closeTermAccount
│   └── transactions.ts  # listTransactions, createTransaction (no update/delete)
├── components/    # ui/ (shadcn), layout/, auth/, transactions/, investments/, instruments/
├── context/       # AuthContext — JWT storage in localStorage, login/logout
├── hooks/         # React Query hooks
│   ├── useBanks.ts       # useBanks, useAccounts, useCreateAccount, useUpdateAccount, useCloseAccount, useDeleteAccount
│   ├── useTermAccounts.ts # useTermAccounts, useCreateTermAccount, useCloseTermAccount
│   └── useTransactions.ts # useTransactions, useCreateTransaction
├── pages/         # One file per route
└── types/         # Shared TypeScript interfaces matching backend schemas
```

**React Query keys**: `['banks']`, `['accounts']`, `['term-accounts']`, `['transactions', params]`, `['investments', params]`, `['platform-accounts']`, `['instruments']`, `['tracked-instruments']`, `['reports/dashboard']`, `['reports/spending-trends']`, `['reports/investment-summary']`

**Mutation invalidation**: `useCreateTransaction` invalidates `accounts` + `term-accounts` (balance changes). `useCreateTermAccount` / `useCloseTermAccount` invalidate both `term-accounts` + `accounts`. `useCloseAccount` invalidates `accounts`.

**API client** (`api/client.ts`): single Axios instance with `baseURL: "/api/v1"`. Request interceptor attaches `Authorization: Bearer <token>` from localStorage. Response interceptor clears token and redirects to `/login` on 401.

**Routing**: `App.tsx` uses React Router v7. Public: `/login`. Protected: `/`, `/transactions`, `/investments`, `/accounts`, `/platform-accounts`, `/instruments`, `/reports`. All wrapped in `ProtectedRoute` → `AppShell`.

**TransactionForm** (`components/transactions/TransactionForm.tsx`): create-only (no edit). Linked account select combines `accounts` + `term_accounts` under a single polymorphic key `"account:<id>"` / `"term_account:<id>"`. `bank_ref` field shown only when `type === 'credit'`. Tags as comma-separated text input → `string[]`.

**AccountsPage** (`pages/AccountsPage.tsx`): two sections — regular accounts table + term accounts (FD/PPF) table. No balance input on create (balance is transaction-driven). Account and term account close dialogs use `closed_date` + `closed_amount`.

**InstrumentCombobox** (`components/instruments/InstrumentCombobox.tsx`): `@base-ui/react` Popover does **not** support `asChild` — style `PopoverTrigger` directly.

**State**: TanStack Query manages all server state. No manual cache writes.

## Design Documentation

Detailed HLD/LLD lives in `docs/`:
- [docs/backend-architecture.md](docs/backend-architecture.md) — full DB schema (SQL), request lifecycle, service patterns, auth flow, test strategy
- [docs/frontend-architecture.md](docs/frontend-architecture.md) — routing, state management, Axios interceptors, form patterns, chart setup
- [docs/dev-commands.md](docs/dev-commands.md) — auto-generated log of all Bash commands run (written by Claude Code hook)

## Claude Code Hooks

`.claude/settings.json` registers PostToolUse hooks that run automatically:
- **Bash hook**: logs every command (with timestamp) to `docs/dev-commands.md`
- **Edit/Write hook (backend)**: when a `.py` file under `backend/` changes, an agent checks whether the change is architecturally significant and surgically updates `docs/backend-architecture.md`
- **Edit/Write hook (frontend)**: same for `.ts`/`.tsx` files under `frontend/src/` → `docs/frontend-architecture.md`

Do not manually rewrite those doc files wholesale — the hooks maintain them incrementally.

## Code Review Graph

A knowledge graph is indexed over the full codebase (686 nodes, 4235 edges). **Use MCP graph tools before reading files** to save tokens:

```
# Find a function/class by name
semantic_search_nodes_tool("create_term_account")

# Understand callers/callees
query_graph_tool(pattern="callers_of", node="create_transaction")
query_graph_tool(pattern="callees_of", node="_apply_balance_delta")

# Impact analysis before a change
get_impact_radius_tool(node="Transaction")

# Efficient review context
get_review_context_tool(file="backend/app/services/transaction_service.py")
```

Rebuild after significant changes:
```bash
# From project root — full rebuild
# (use MCP tool: build_or_update_graph_tool with full_rebuild=true)
```

## API Structure

All endpoints under `/api/v1/`. Protected routes require `Authorization: Bearer <token>`.

| Domain | Prefix | Key endpoints |
|--------|--------|---------------|
| Auth | `/auth` | POST `/login`, GET `/me`, PUT `/me` |
| Transactions | `/transactions` | POST (create), GET (list + filters: type credit/debit, date range, pagination) — no PUT/DELETE |
| Investments | `/investments` | Full CRUD + `?type=` multi-filter |
| Reports | `/reports` | GET `/dashboard`, `/spending-trends`, `/investment-summary` |
| Instruments | `/instruments` | Full CRUD; POST/DELETE `/{id}/track`; GET `/tracked` |
| Banks | `/banks` | GET (read-only list) |
| Accounts | `/accounts` | CRUD + POST `/{id}/close` |
| Term Accounts | `/term-accounts` | GET (list), POST (create), GET `/{id}`, POST `/{id}/close` |
| Platforms | `/platforms` | GET (read-only list) |
| Platform Accounts | `/platform-accounts` | Full CRUD |
| Follios | `/follios` | Full CRUD |

## Environment

`backend/.env` (gitignored):
```
DATABASE_URL=postgresql+psycopg://fintrack_user:password@localhost:5432/fintrack_db
SECRET_KEY=<32-byte hex from secrets.token_hex(32)>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
ENVIRONMENT=development
```

## Key Constraints

- SQLAlchemy dialect must be `postgresql+psycopg://` (psycopg3), not `postgresql://` (psycopg2).
- `alembic/env.py` must import all models so autogenerate detects schema changes. All models re-exported from `app/models/__init__.py`.
- When a PostgreSQL enum type already exists (created in a prior migration), use `postgresql.ENUM(..., create_type=False)` from `sqlalchemy.dialects.postgresql` — not `sa.Enum(..., create_type=False)`.
- The SPA catch-all route in `main.py` must be registered **after** all `/api/v1/` routers.
- Alembic migration revision IDs are datetime-stamped; sleep ≥2s between generating multiple migrations or they collide.
- No downgrade migrations — write a new migration for any schema change.
- `bulk_save_objects` in seed bypasses service-layer balance hooks — seed transactions do not auto-update account balances.
- Zod v4, Tailwind v4, React Router v7, Recharts v3, and TypeScript v6 all have breaking changes — check migration guides before upgrading.
- `@base-ui/react` Popover does not support `asChild` (unlike Radix UI).
