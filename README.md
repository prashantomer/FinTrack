# FinTrack

> Take control of your finances — track every rupee, every account, every investment, in one place.

FinTrack is a self-hosted personal finance tracker built as a **single-origin monolith**: one Rails process serves both the REST API and (in production) the compiled React SPA. No cloud dependencies, no subscriptions — just your data, on your machine.

---

## What you can track

| Domain | Details |
|--------|---------|
| **Bank Accounts** | Savings, current, salary, NRE/NRO — with full transaction history and balance audit log |
| **Investments** | Stocks, mutual funds — linked to instruments and platform accounts |
| **Fixed Deposits** | Linked to parent savings accounts, auto-calculates maturity date & amount (quarterly compounding) |
| **PPF** | 15-year tenure, deposit tracking, balance driven by transactions |
| **Portfolio** | Position-level view with lots, avg buy price, unrealized gain/loss |
| **Portfolio** | Position-level view with lots, avg buy price, unrealized gain/loss |
| **Reports** | Net worth, spending trends, investment summary — Redis-cached for instant loads |
| **CSV Import** | Bulk-import investments, bank transactions, and term accounts from CSV; async Sidekiq processing with live progress, import versioning, and per-row error reporting |
| **Audit Log** | Every balance change on accounts and term accounts is traceable to the transaction that caused it |

---

## Tech Stack

**Backend** — Ruby 3.x · Rails 8.1 · PostgreSQL · Redis · Sidekiq · Puma · `jwt` + `bcrypt` · `audited`

**Frontend** — React 19 · TypeScript · Vite 8 · TanStack Query v5 · shadcn/ui · Recharts · Tailwind CSS v4

---

## Prerequisites

- [rbenv](https://github.com/rbenv/rbenv) or [asdf](https://asdf-vm.com/) — Ruby version manager
- [nvm](https://github.com/nvm-sh/nvm) — Node version manager
- **PostgreSQL** running locally
- **Redis** running locally — required for Sidekiq (CSV imports); dashboard caching also uses it but falls back to direct DB queries without it

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/prashantomer/FinTrack.git
cd FinTrack
```

### 2. Set up runtimes

```bash
# Node 24 LTS (reads .nvmrc automatically)
source ~/.nvm/nvm.sh && nvm install
```

### 3. Set up the database

```bash
createdb fintrack_development
createuser fintrack_user --pwprompt
psql -c "GRANT ALL ON DATABASE fintrack_development TO fintrack_user;"
```

### 4. Configure the backend

Edit `backend/config/database.yml` or set `DATABASE_URL` in `backend/.env`:

```env
DATABASE_URL=postgresql://fintrack_user:your_password@localhost:5432/fintrack_development
SECRET_KEY_BASE=<output of: bundle exec rails secret>
REDIS_URL=redis://localhost:6379/0   # optional — remove to disable caching
```

### 5. Install backend dependencies & run migrations

```bash
cd backend
bundle install
bundle exec rails db:migrate
```

### 6. Seed reference data

Banks and investment platforms are admin-managed — seed them once:

```bash
bundle exec rails db:seed
```

### 7. Create your user

There is no public registration. Create a user from the Rails console:

```bash
bundle exec rails console
User.create!(email: "you@example.com", first_name: "First", last_name: "Last", password: "yourpassword")
```

### 8. Install frontend dependencies

```bash
cd ../frontend
source ~/.nvm/nvm.sh && nvm use
npm install
```

---

## Running in Development

Use `make dev` from the project root (requires [foreman](https://github.com/ddollar/foreman)):

```bash
make dev
# Starts Rails on :8000, Vite on :5173, and Sidekiq — all via foreman
```

Or start each process manually:

**Terminal 1 — Backend** (Rails on port 8000):
```bash
cd backend
bundle exec rails server -p 8000
# → API at http://localhost:8000/api/v1
# → Swagger UI at http://localhost:8000/api-docs
```

**Terminal 2 — Sidekiq** (background job processor — required for CSV imports):
```bash
cd backend
bundle exec sidekiq -C config/sidekiq.yml
```

**Terminal 3 — Frontend** (HMR, proxies `/api` → `:8000`):
```bash
cd frontend
npm run dev
# → http://localhost:5173
```

Open `http://localhost:5173` and log in with the credentials you created above.

---

## Running in Production

Build the frontend once, then serve everything from a single Rails process:

```bash
cd frontend && npm run build

cd ../backend
RAILS_ENV=production bundle exec rails server -p 8000
```

---

## Project Structure

```
FinTrack/
├── backend/                    # Rails 8.1 API
│   ├── app/
│   │   ├── controllers/api/v1/ # Route handlers (thin — delegate to services)
│   │   ├── models/             # ActiveRecord models with validations & enums
│   │   ├── services/           # Business logic (QueryService, CreateService, etc.)
│   │   └── serializers/        # JSON serialization
│   ├── config/routes.rb        # All API routes under /api/v1
│   ├── db/schema.rb            # Canonical DB schema
│   └── spec/                   # RSpec test suite
└── frontend/
    └── src/
        ├── api/           # Axios call functions per domain
        ├── components/    # UI components (shadcn/ui + custom)
        ├── hooks/         # TanStack Query hooks
        ├── pages/         # One file per route
        └── types/         # TypeScript interfaces matching backend serializers
```

---

## Useful Commands

```bash
# Run backend tests (RSpec)
cd backend && bundle exec rspec

# Type-check the frontend
cd frontend && npx tsc --noEmit

# Generate a new DB migration
cd backend && bundle exec rails generate migration DescribeYourChange

# Run migrations
cd backend && bundle exec rails db:migrate

# Open Rails console
cd backend && bundle exec rails console

# Rebuild Swagger docs from RSpec specs
cd backend && bundle exec rails rswag:specs:swaggerize
```

---

## API Documentation

Interactive Swagger UI is available at `http://localhost:8000/api-docs` when the backend is running.

---

## Design Documentation

Detailed architecture lives in `docs/`:
- [docs/backend-architecture.md](docs/backend-architecture.md) — full DB schema, request lifecycle, service patterns, auth flow, test strategy
- [docs/frontend-architecture.md](docs/frontend-architecture.md) — routing, state management, Axios interceptors, form patterns, chart setup

---

## License

MIT — see [LICENSE](LICENSE).
