# FinTrack Development Roadmap

Each step is self-contained and verifiable before moving to the next. Status is updated after each session.

---

## Progress Tracker

| Step | Title | Status | Completed |
|------|-------|--------|-----------|
| 1 | Backend foundation | ✅ Done | 2026-04-28 |
| 2 | Authentication API | ✅ Done | 2026-04-28 |
| 3 | Transactions API | ✅ Done | 2026-04-28 |
| 4 | Investments API | ✅ Done | 2026-04-28 |
| 5 | Reports API | ✅ Done | 2026-04-28 |
| 6 | Frontend foundation | ✅ Done | 2026-04-28 |
| 7 | Auth UI (login + register) | ✅ Done | 2026-04-28 |
| 8 | Transactions UI | ✅ Done | 2026-04-28 |
| 9 | Investments UI | ✅ Done | 2026-04-28 |
| 10 | Dashboard + Reports UI | ✅ Done | 2026-04-28 |
| 11 | Polish + production build | ✅ Done | 2026-04-28 |

**Status key**: ⬜ Not started · 🔄 In progress · ✅ Done

---

## Step 1 — Backend Foundation

**Goal**: A running FastAPI app connected to PostgreSQL with all three ORM models and an initial migration applied.

### What gets built
- `backend/` initialised via `uv init --app --python 3.13.5`
- `pyproject.toml` — single source of truth for all pinned deps (replaces `requirements.txt`)
- `.venv/` managed automatically by `uv`
- `main.py` — root entry point (`uv run fastapi dev main.py` discovers it)
- `app/config.py` — pydantic-settings reads `backend/.env`
- `app/database.py` — SQLAlchemy engine + `SessionLocal` + `Base`
- `app/models/user.py`, `transaction.py`, `investment.py` — all ORM models
- `app/main.py` — FastAPI app factory, health check at `GET /api/v1/health`
- `alembic/` setup + `alembic.ini`
- Migration `e8025f73c35a_initial_schema` — creates `users`, `transactions`, `investments` tables
- `backend/.env` (gitignored; created once with DB URL + secret key)

### How to verify
```bash
cd backend
uv run alembic upgrade head           # no errors
uv run fastapi dev main.py            # server at :8000, docs at /docs
curl http://localhost:8000/api/v1/health  # → {"status":"ok"}
```
```sql
-- In psql fintrack_db:
\dt   -- alembic_version, investments, transactions, users
```

### ✅ Completed — 2026-04-28
Tooling: `uv 0.11.8` · Migration: `e8025f73c35a` · DB: `fintrack_db` (owner: `fintrack_user`)

---

## Step 2 — Authentication API

**Goal**: CLI-based user creation + JWT login; protected `GET /me` and `PUT /me`. All data isolated per user.

### What gets built
- `app/schemas/user.py` — `UserRead`, `UserUpdate`, `Token`, `TokenData`
- `app/services/auth_service.py` — `create_user()`, `authenticate_user()`, `create_access_token()`, `decode_token()`
- `app/dependencies.py` — `get_db()`, `get_current_user()`
- `app/routers/auth.py` — `POST /login`, `GET /me`, `PUT /me` (no public register)
- `app/cli.py` — `uv run python -m app.cli create-user` (prompts email, name, password; `--generate` flag)
- `tests/conftest.py` — `fintrack_test_db`, rollback-per-test `db` fixture, `client`, `auth_client`
- `tests/test_auth.py` — 6 tests

**Design decision**: No `POST /register` endpoint. Users are created from the terminal only (admin-only, Rails-console style).

**Dependency note**: `bcrypt==4.0.1` pinned — `passlib 1.7.4` is incompatible with `bcrypt 5.x`.

### How to verify
```bash
cd backend

# Create a user
uv run python -m app.cli create-user
# → prompts email / name / password, prints confirmation

# Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=<email>&password=<password>"
# → {"access_token":"...","token_type":"bearer"}

# Tests
uv run pytest tests/test_auth.py -v   # 6 passed
```

### ✅ Completed — 2026-04-28
6/6 tests passing · `bcrypt==4.0.1` pinned for passlib compat · test DB: `fintrack_test_db`

---

## Step 3 — Transactions API

**Goal**: Full CRUD for transactions with filtering and pagination.

### What gets built
- `app/schemas/transaction.py` — `TransactionCreate`, `TransactionRead`, `TransactionListResponse`
- `app/utils/pagination.py` — `PaginationParams`
- `app/services/transaction_service.py`
- `app/routers/transactions.py` — `GET /`, `POST /`, `GET /{id}`, `PUT /{id}`, `DELETE /{id}`
- `tests/test_transactions.py`

### Query filters supported
- `?type=income|expense`
- `?category=food|transport|...`
- `?date_from=YYYY-MM-DD&date_to=YYYY-MM-DD`
- `?page=1&page_size=20`

### How to verify
```bash
cd backend && pytest tests/test_transactions.py -v
```
Check that a non-owner cannot access another user's transaction (403).

---

## Step 4 — Investments API

**Goal**: Full CRUD for investments; all 8 types validated via Pydantic discriminated unions.

### What gets built
- `app/schemas/investment.py` — discriminated union per investment type
- `app/services/investment_service.py`
- `app/routers/investments.py` — `GET /`, `POST /`, `GET /{id}`, `PUT /{id}`, `DELETE /{id}`
- Filter: `?type=stock&type=mutual_fund` (multi-value)
- `tests/test_investments.py`

### How to verify
```bash
cd backend && pytest tests/test_investments.py -v
```
Create one of each investment type and confirm type-specific fields are stored/returned correctly.

---

## Step 5 — Reports API

**Goal**: Four read-only aggregation endpoints that power the dashboard.

### What gets built
- `app/schemas/reports.py` — `DashboardSummary`, `SpendingTrend`, `CategoryBreakdown`, `InvestmentSummary`
- `app/services/report_service.py` — SQL aggregation queries (`SUM`, `GROUP BY`, `date_trunc`)
- `app/routers/reports.py`:
  - `GET /dashboard` — income, expenses, balance, portfolio value
  - `GET /spending-trends` — monthly income vs expense for trailing 6 months
  - `GET /category-breakdown` — spending per category for a given month
  - `GET /investment-summary` — total invested, current value, gain/loss per type
- `tests/test_reports.py`

### How to verify
```bash
cd backend && pytest tests/test_reports.py -v
cd backend && pytest   # full suite green
```

---

## Step 6 — Frontend Foundation

**Goal**: Vite + React + TypeScript project with routing, auth context, Axios client, and shadcn/ui base components. No real pages yet — just the shell.

### What gets built
- `frontend/` scaffold via `npm create vite@latest`
- `package.json` with all pinned versions installed
- `vite.config.ts` — `/api` proxy to `localhost:8000`
- `tsconfig.json` — strict mode, path aliases
- `tailwind.config.ts` — Tailwind v4 CSS-first setup
- `components.json` — shadcn/ui config
- Initial shadcn/ui components: `Button`, `Card`, `Input`, `Label`, `Form`, `Select`, `Dialog`, `Table`, `Badge`, `Separator`, `Toaster`
- `src/lib/utils.ts` — `cn()`, `formatCurrency()`, `formatDate()`
- `src/api/client.ts` — Axios instance with auth + 401-logout interceptors
- `src/context/AuthContext.tsx`
- `src/App.tsx` — router with `ProtectedRoute` + `AppShell` layout
- `src/components/layout/` — `AppShell`, `Sidebar`, `Header`
- `src/components/auth/ProtectedRoute.tsx`
- Placeholder pages: Dashboard, Transactions, Investments, 404

### How to verify
```bash
source ~/.nvm/nvm.sh && nvm use
cd frontend && npm run dev
# Open http://localhost:5173
# /login renders (no crash)
# Navigating to / redirects to /login (ProtectedRoute works)
cd frontend && npx tsc --noEmit   # no type errors
```

---

## Step 7 — Auth UI (Login + Register)

**Goal**: Working login and register pages that issue a real JWT and redirect to the dashboard.

### What gets built
- `src/types/auth.ts`
- `src/api/auth.ts` — `login()`, `register()`, `getMe()`
- `src/hooks/useAuth.ts` — `useCurrentUser()`
- `src/pages/LoginPage.tsx`
- `src/pages/RegisterPage.tsx`
- Form validation via `react-hook-form` + Zod

### How to verify
- Register a new user → redirected to `/`
- Log in with those credentials → redirected to `/`
- Invalid credentials → inline error message shown
- Refresh page → still logged in (token persisted in localStorage)
- Click logout → redirected to `/login`, token cleared

---

## Step 8 — Transactions UI

**Goal**: List, create, edit, and delete transactions with filters.

### What gets built
- `src/types/transaction.ts`
- `src/api/transactions.ts`
- `src/hooks/useTransactions.ts`
- `src/components/transactions/TransactionTable.tsx`
- `src/components/transactions/TransactionForm.tsx` (create + edit in a Dialog)
- `src/components/transactions/TransactionFilters.tsx`
- `src/pages/TransactionsPage.tsx`

### How to verify
- Create an income and an expense → appear in the table
- Edit a transaction → updates in place
- Delete a transaction → removed from list
- Filter by type, category, date range → correct subset shown
- Pagination works for > 20 rows

---

## Step 9 — Investments UI

**Goal**: List, create, edit, and delete investments; form fields change per investment type.

### What gets built
- `src/types/investment.ts`
- `src/api/investments.ts`
- `src/hooks/useInvestments.ts`
- `src/components/investments/InvestmentTable.tsx`
- `src/components/investments/InvestmentForm.tsx` — `watch("type")` switches field groups
- Type-specific field sub-components: `StockFields`, `MutualFundFields`, `FixedDepositFields`, `GoldFields` (others as needed)
- `src/pages/InvestmentsPage.tsx`

### How to verify
- Create one investment of each type → all stored correctly
- Switch type in the form → fields change, no stale data bleeds across
- Edit an existing investment → values pre-filled correctly
- Delete works
- Filter by type works

---

## Step 10 — Dashboard + Reports UI

**Goal**: The dashboard page shows summary cards, a spending trend chart, a category breakdown pie, and an investment summary.

### What gets built
- `src/types/reports.ts`
- `src/api/reports.ts`
- `src/hooks/useReports.ts`
- `src/components/dashboard/SummaryCards.tsx` — Income / Expenses / Balance / Portfolio value
- `src/components/dashboard/SpendingChart.tsx` — Recharts `ComposedChart` (bars + line, 6-month trend)
- `src/components/dashboard/CategoryPieChart.tsx` — Recharts `PieChart` with legend
- `src/pages/DashboardPage.tsx`

### How to verify
- Dashboard loads without errors after seeding transactions + investments
- Summary card numbers match what the backend returns
- Spending chart shows correct months
- Pie chart segments match category totals
- All charts are responsive (resize browser window)

---

## Step 11 — Polish + Production Build

**Goal**: The monolith works end-to-end from a single `uvicorn` process; no open issues.

### What gets built / fixed
- Loading states on all data-fetching components
- Error states (API down, 4xx)
- Empty states (no transactions yet, etc.)
- Mobile-responsive sidebar (collapsible)
- Production build tested locally
- `backend/main.py` SPA static mount verified

### How to verify
```bash
cd frontend && npm run build        # no type or lint errors
cd backend && uvicorn app.main:app --host 0.0.0.0 --port 8000
# Open http://localhost:8000
# All features work from this single origin
# API calls go to /api/v1/ (not port 5173 dev proxy)
cd frontend && npx tsc --noEmit
cd frontend && npm run lint
cd backend && pytest                 # all tests still green
```

---

## Session Notes

_Record what was completed, any decisions made, or blockers encountered._

| Date | Notes |
|------|-------|
| 2026-04-28 | Step 1 complete (redone with `uv`). `uv init --app` replaced manual pip/venv setup. `pyproject.toml` manages all deps. Migration `e8025f73c35a_initial_schema` applied — `users`, `transactions`, `investments` live in `fintrack_db`. Server starts with `uv run fastapi dev main.py`. Health check confirmed `{"status":"ok"}`. |
