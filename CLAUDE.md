# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Project Overview

FinTrack is a personal finance tracker. Two processes:

- **Backend** — Rails 8.1 API on port 8000. Sidekiq workers for background jobs.
- **Frontend** — Vite + React 19 SPA on port 5173. The Vite dev server proxies `/api` and `/rails` to the Rails app.

There used to be a FastAPI backend under `backend_python/`; that tree has been removed. The current home of all server code is `backend/`.

## Runtime Versions

| Runtime    | Pin       | Manager       |
|------------|-----------|---------------|
| Ruby       | `3.3.4`   | rbenv / rvm (`.ruby-version`) |
| Node.js    | `24.x` LTS | nvm (`.nvmrc`) |
| PostgreSQL | 14+       | brew          |
| Redis      | 7+        | brew          |

```bash
rvm use 3.3.4
source ~/.nvm/nvm.sh && nvm install   # reads .nvmrc

cd backend && bundle install
cd ../frontend && npm install
```

## Common Commands

### One-time setup

```bash
brew services start postgresql@16
brew services start redis

createdb fintrack_db
createuser fintrack_user --pwprompt
psql -c "GRANT ALL ON DATABASE fintrack_db TO fintrack_user;"
psql -c "ALTER USER fintrack_user CREATEDB;"   # required for tests

cd backend
bin/rails db:setup            # create + migrate
bin/rails banks:seed          # bank list
bin/rails platforms:seed      # broker / MF platform list
bin/rails users:create        # interactive — creates the first user

# Wire the pre-push gate (one-time per clone)
cd .. && bin/setup
```

### Creating a user

No public registration — users are created from the CLI.

```bash
cd backend
bin/rails users:create        # interactive: email, name, password
bin/rails users:wipe          # delete a user + all their data
bin/rails users:list
```

### Seeding banks, platforms, instruments

```bash
cd backend
bin/rails banks:seed                       # idempotent upsert from db/seeds/banks.csv
bin/rails platforms:seed                   # broker / MF platform list
bin/rails instruments:fetch                # NSE EQ + AMFI scheme catalogue (one-time)
bin/rails instruments:fetch_prices         # latest close prices into instruments.last_price + history
```

### Backend dev

```bash
cd backend
bin/rails server                           # http://localhost:8000
bundle exec sidekiq                        # background workers — separate terminal
# OR start backend + sidekiq + frontend together:
foreman start -f Procfile.dev              # uses bin/dev under the hood
```

```bash
# Tests
cd backend
bundle exec rspec                          # full suite
bundle exec rspec spec/services            # one folder
bundle exec rspec spec/models/user_spec.rb:42

# Migrations (datetime-stamped revision IDs)
bin/rails g migration AddSomethingToSomething field:type
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate

# No downgrade migrations — write a new one for every change
```

### Transaction admin (CLI only)

Structural changes to transactions (amount, type, linked account) and any deletion are CLI-only — no DELETE endpoint exists, and PUT only accepts `description` + `tags` on `source=manual` rows. Use the rake tasks for everything else:

```bash
cd backend
bin/rails transactions:correct ID=123      # update amount/type and reverse balance impact
bin/rails transactions:deactivate ID=123   # soft-delete and reverse balance
```

### AI Assistant

```bash
cd backend
bin/rails assistant:configure              # interactive: provider, model, api_key
bin/rails assistant:status                 # ping configured provider
```

### Daily price fetch + P&L tracking

```bash
cd backend
bin/rails daily:pnl                        # run synchronously
bin/rails daily:status                     # last-run state per scheduled task
```

### Frontend

```bash
cd frontend
source ~/.nvm/nvm.sh && nvm use            # ensure Node 24

npm run dev                                # http://localhost:5173 (proxies /api → 8000)
npm run build                              # production build → frontend/dist/
npx tsc --noEmit                           # typecheck
npm run lint                               # ESLint
```

### Pre-push gate

`bin/pre-push-checks` runs every quality gate (rubocop, brakeman, bundler-audit, eslint, tsc, vite build, rspec) in parallel. Wired as a git hook via `.githooks/pre-push`; `bin/setup` plus the frontend `npm postinstall` arm `core.hooksPath` on a fresh clone, so manual `git push` always runs the gate. `--no-verify` bypasses for emergencies.

### Production

```bash
cd frontend && npm run build               # outputs to frontend/dist/, served by Nginx in prod
cd backend
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails server -p 8000
RAILS_ENV=production bundle exec sidekiq   # separate process
```

## Architecture

### Backend (`backend/`)

**Stack**: Rails 8.1 + PostgreSQL via `pg` gem + Sidekiq (Redis) + Puma + JWT auth + `audited` for change history + Active Record encryption + ActiveStorage.

```
backend/
├── app/
│   ├── controllers/api/v1/      # Thin controllers, render via serializers
│   │   └── assistant/           # Assistant routes (messages, attachments, sessions, settings)
│   ├── jobs/                    # Sidekiq jobs (Daily::PriceAndPnlSnapshotJob, Holdings::RefreshJob, Imports::*)
│   ├── models/                  # ActiveRecord models (annotated by annotaterb)
│   ├── serializers/             # Plain-Ruby serializers, no jbuilder
│   └── services/                # Business logic — assistants, holdings, imports, reports, queries, ...
├── config/
│   ├── routes.rb
│   ├── sidekiq.yml              # queue names + concurrency
│   ├── sidekiq_cron.yml         # scheduled jobs (daily price + P&L snapshot)
│   └── initializers/
│       └── daily_pnl_catchup.rb # boot-time catch-up if 5 AM tick was missed
├── db/migrate/                  # Datetime-stamped migrations
├── lib/tasks/                   # Rake tasks (users, banks, platforms, instruments, daily, assistant)
└── spec/                        # RSpec
```

**Auth**: JWT (HS256, 7-day expiry) issued by `Api::V1::AuthController#login`. Passwords hashed with `bcrypt` via `has_secure_password`. The `Authenticatable` concern resolves `current_user` from the `Authorization: Bearer <token>` header on every protected route.

**Transaction model** (`app/models/transaction.rb`):

- `transaction_type`: `credit` | `debit`
- `linked_account_type` + `linked_account_id`: polymorphic association — `Account` (savings) or `TermAccount` (FD/PPF). Resolved at the model level via `belongs_to :linked_account, polymorphic: true`.
- `tags`: `string[]`, free-form labels.
- `bank_ref`: UTR/IMPS reference for credit transactions.
- `is_active`: soft-delete; rake task `transactions:deactivate` flips it and reverses balance impact.
- `source`: `manual` | `imported`. Manual rows came from the API/UI; imported rows came through `Imports::*` and are frozen.
- **No DELETE from the API** — corrections and soft-deletes live in the rake tasks. **PUT** is allowed only on `source=manual` rows and is whitelisted to `description` + `tags`; structural fields stay CLI-only.

**Balance hooks** (`Transactions::CreateService`, rake tasks): `credit` adds, `debit` subtracts on the linked savings account. FD term accounts skip balance updates (FD balance tracks principal). The CLI `correct` flow reverses the old delta and applies the new one in a transaction.

**Term accounts** (`app/models/term_account.rb`, STI): `account_type` = `fd` | `ppf`. FD creation in `TermAccounts::CreateService` validates parent savings balance, creates paired savings-debit + FD-credit transactions, and stores `maturity_date` / `maturity_amount` (FD = `amount * (1 + rate/100 * tenure_days/365)`; PPF = `open_date + 15.years`, user-supplied amount).

**Holdings (STI cache)** — `app/models/holding.rb` with two subclasses:

- `Folio` — mutual-fund holdings (carries `folio_number`).
- `EquityHolding` — stock holdings (no folio number).

Holdings cache aggregated stats per `(user_instrument × platform_account)` — `total_units`, `avg_buy_price`, `total_invested`, `current_value`, `unrealized_gain`, `realized_gain`, `long_term_units`, `short_term_units`. Refreshed by `Holdings::RefreshJob` after every Investment write (controlled by `Current.skip_holding_refresh` for bulk imports).

**FIFO portfolio math** lives in `Holdings::PositionCalculator` — pure function, single source of truth for cost basis, realized + unrealized P&L, and the LT/ST 365-day split. Both `Holdings::RefreshService` (writes `Holding` cache) and `Reports::PortfolioService` (live snapshot) read from it.

**Daily price + P&L snapshot** (`Daily::PriceAndPnlSnapshotJob`, fires at 05:00 IST via sidekiq-cron):

1. `Instruments::PriceFetchService.call` — pulls NSE bhavcopy + AMFI NAVs into `instruments.last_price` and appends `instrument_price_history` rows (idempotent upsert).
2. `Reports::HoldingSnapshotService.snapshot_all!` — refreshes every active holding and writes `holding_snapshots` rows for that date.
3. Stamps `SystemTask("daily_pnl")` so `daily_pnl_catchup.rb` can detect a missed run on the next boot and enqueue catch-up.

Same-day re-runs upsert in place: `created_at` survives, `updated_at` bumps, `update_only` is restricted to the stat columns.

**Historical price backfill** (`Instruments::PriceBackfillService` + the two `Instruments::Backfill*Job`s on the `:price_backfill` Sidekiq queue):

- Bulk path: `bin/rails instruments:backfill_prices DAYS=365` enumerates tracked instruments and fans out one NSE job per trading weekday + one AMFI job per 30-day chunk. Idempotent via the `(instrument_id, price_date)` unique index.
- Per-track path: `Instruments::TrackService#track` enqueues `Instruments::FirstTimeBackfillJob` whenever a fresh `UserInstrument` row is created (default `backfill: true`). The job calls `Instruments::PriceBackfillScheduler.enqueue_for(instrument)`, which scopes the same per-day NSE / per-range AMFI work to a single id/ISIN and **skips dates already covered** by the daily fetch (cheap pre-flight via `InstrumentPriceHistory.pluck(:price_date)`). Bulk callers (CSV importer) opt out with `track(backfill: false)` so a 100-row import doesn't fan out 25k+ jobs — run the rake task once after a big import instead.
- Source strings differ on purpose: daily writes `nse_bhavcopy` / `amfi_navall`, backfill writes `nse_bhavcopy` (NSE source format is identical) / `amfi_navhistory`. The portal endpoint AMFI history uses a different column order than `NAVAll.txt` (scheme name before ISIN, repurchase + sale-price columns before the date) — the parser indexes accordingly.

**Importer** (`Imports::Process*RowService` per type, kicked off by Sidekiq jobs):

- Investment CSVs: `Imports::InvestmentFormatAdapters` auto-detects Zerodha Coin (`segment=MF`) and Kite (`segment=EQ`) tradebooks; everything else uses the `Default` adapter that expects FinTrack's canonical schema.
- All three importers run a duplicate-detection ladder before insert. Per type:
  - Investments → `trade_id` → `(order_id, purchase_date)` → structural `(user_instrument, platform_account, date, amount, side)`.
  - Transactions → `bank_ref` → `(date, amount, type, linked_account)`.
  - Term accounts → `(account_type, account_number)` → structural.
- Duplicate rows write a `:skipped` `ImportRecord` whose `notes` cite the matched record (`"Duplicate of Investment #842 (trade_id 4089431)"`) and bump `import_batches.duplicate_rows`.
- Files attach to `ImportBatch` via ActiveStorage (`has_one_attached :file`).

**AI Assistant** (`app/services/assistants/`):

- `Conversation.run!` orchestrates a single chat turn: builds context, calls the configured provider, executes any tool-use the provider returns, persists messages.
- Provider abstraction: `Anthropic`, `OpenAI`, `Ollama` — selected per user via `UserAssistantSetting` (singleton row per user; `api_key` encrypted at rest via Active Record encryption).
- Tools (`Assistants::Tools::*`) are user-scoped — every tool ctor takes `user`, the LLM never supplies a user id. Coverage: query_transactions, query_investments, query_holdings, query_term_accounts, query_dashboard, query_spending, lookup_instruments, analyse_csv, generate_import_csv, explain_portfolio_pnl.
- Conversations are persisted as `AssistantMessage` rows with `role: user | assistant | tool`. Pinned messages always make it back into context.

**Reference data** (admin-managed, CLI-only):

- `banks` + `accounts` — global bank list; users create their own `accounts` via API. `Bank.short_name` is unique, max 6 chars.
- `platforms` + `platform_accounts` — global broker / MF platform list; users create `platform_accounts`.
- `instruments` — global catalogue of investable securities. Users add to their watchlist via `user_instruments`.

**Database connection**: `pg` adapter, `DATABASE_URL=postgresql://…`. `database.yml` reads from env.

**Migrations**: datetime-stamped revision IDs (`20260507175456_*`). No downgrade migrations — write a new one for every change. Sleep ≥1 s between generating two migrations to avoid timestamp collisions.

### Frontend (`frontend/`)

**Stack**: React 19 + TypeScript 5 + Vite 8 + React Router v7 + TanStack Query v5 + base-ui + Tailwind v4 + Recharts 3 + lucide-react + sonner.

```
frontend/src/
├── api/           # Axios call functions per domain (banks, holdings, imports, …)
├── components/    # ui/ (shadcn-style + base-ui), accounts/, assistant/, imports/, …
├── context/       # AuthContext — JWT in localStorage
├── hooks/         # React Query hooks — useHoldings, useInvestments, useAssistantChat, …
├── lib/           # finance.ts, errors.ts, errorReporter.ts
├── pages/         # One file per route
└── types/         # Shared TS interfaces matching backend serializers
```

**API client** (`api/client.ts`): single Axios instance, `baseURL: "/api/v1"`. Bearer-token request interceptor; 401 response interceptor clears the token and bounces to `/login`.

**Routing** (`App.tsx`): `/` is the public `LandingPage`; `/login` is public; everything else is wrapped in `ProtectedRoute → AppShell` (`/dashboard`, `/accounts`, `/transactions`, `/platform-accounts`, `/instruments`, `/holdings`, `/investments`, `/portfolio`, `/reports`, `/imports`, `/assistant`).

**TransactionForm**: create-only. Linked account select combines `accounts` + `term_accounts` under `"account:<id>"` / `"term_account:<id>"` polymorphic keys.

**Holdings page**: active / closed split, click-through to a `PositionLotsSheet` showing every lot. MF folio numbers are inline-editable.

**State**: TanStack Query for all server state — no manual cache writes outside `useAssistantChat`'s mutation flow.

**Select component** (`components/ui/select.tsx`): wraps `@base-ui/react/select`, specialised to `string`. The wrapper exposes a clean `(value: string) => void` callback that collapses base-ui's `string | null` at the boundary.

**Important base-ui gotcha**: `@base-ui/react`'s `Popover` does **not** support `asChild` (unlike Radix). Style the `PopoverTrigger` directly. The `Button` wrapper uses base-ui's `render` prop instead — passing `asChild` nests elements and breaks layout.

## Design Documentation

Detailed docs live in `docs/`:

- [docs/backend-architecture.md](docs/backend-architecture.md) — full DB schema, request lifecycle, service patterns.
- [docs/frontend-architecture.md](docs/frontend-architecture.md) — routing, state management, form patterns, chart setup.
- [docs/dev-commands.md](docs/dev-commands.md) — scenario-grouped command reference.

## Code Review Graph

A knowledge graph is indexed over the codebase. **Use MCP graph tools before reading files** to save tokens:

```
semantic_search_nodes_tool("create_term_account")
query_graph_tool(pattern="callers_of", node="Holdings::RefreshService")
get_impact_radius_tool(node="Investment")
get_review_context_tool(file="backend/app/services/holdings/refresh_service.rb")
```

Rebuild after significant changes via `build_or_update_graph_tool` (the MCP tool, not a CLI).

## API Structure

All endpoints under `/api/v1/`. Protected routes require `Authorization: Bearer <token>`.

| Domain            | Prefix                | Key endpoints |
|-------------------|-----------------------|---------------|
| Auth              | `/auth`               | POST `/login`, GET `/me`, PUT `/me` |
| Transactions      | `/transactions`       | GET (list), POST (create), PUT (manual only — `description`, `tags`). No DELETE. |
| Investments       | `/investments`        | GET (list/show), POST, PUT (manual only — `notes`). No DELETE. |
| Holdings          | `/holdings`           | GET (list with `?type=` `?status=`); POST `/refresh` |
| Reports           | `/reports`            | GET `/dashboard`, `/spending-trends`, `/investment-summary`, `/portfolio` |
| Instruments       | `/instruments`        | Full CRUD; POST/DELETE `/{id}/track`; GET `/tracked` |
| Banks             | `/banks`              | GET (read-only) |
| Accounts          | `/accounts`           | CRUD + POST `/{id}/close` + `/{id}/audit-logs` |
| Term Accounts     | `/term-accounts`      | GET, POST, GET `/{id}`, POST `/{id}/close` + `/{id}/audit-logs` |
| Platforms         | `/platforms`          | GET (read-only) |
| Platform Accounts | `/platform-accounts`  | Full CRUD |
| Imports           | `/imports`            | GET (list), POST (create), GET `/{id}`, GET `/template/{type}` |
| Assistant         | `/assistant/...`      | `messages` (CRUD + pin/unpin), `attachments`, `sessions`, `setting` |
| Errors            | `/errors`             | POST (client-side error reporter) |

Sidekiq Web UI mounted at `/sidekiq` when `SIDEKIQ_USERNAME` and `SIDEKIQ_PASSWORD` are set in the env.

## Environment

`backend/.env` (gitignored):

```
DATABASE_URL=postgresql://fintrack_user:password@localhost:5432/fintrack_db
REDIS_URL=redis://localhost:6379
SECRET_KEY_BASE=<output of: bin/rails secret>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<bin/rails db:encryption:init>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<same>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<same>
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=fintrack-dev
```

Per-user assistant API keys live in `user_assistant_settings.api_key` (encrypted at rest), not in env.

## Key Constraints

- **Time zone**: app is `Asia/Kolkata`. Cron schedules and `Date.current` use IST.
- **Migrations**: write a new one for every change — no downgrades. Sleep ≥1 s between generating two migrations or timestamps collide.
- **Holdings refresh callback**: every `Investment` save fires `Holdings::RefreshJob`. Bulk loaders (CSV importer, future seeders) set `Current.skip_holding_refresh = true` and enqueue a single full-user sweep at the end. The skip flag is per-request via `ActiveSupport::CurrentAttributes`.
- **`Holdings::RefreshService#persist_lot_pnl`** uses `update_columns` to bypass the after_save_commit callback — otherwise touching every lot would re-enqueue a refresh job and loop.
- **Source-of-record gating**: `investments.source` and `transactions.source` distinguish manual UI entries from importer rows. `imported` rows are read-only via the API; `manual` rows accept narrow PUTs (`investments` → `notes`; `transactions` → `description`+`tags`). No DELETE endpoint exists for either; structural corrections and soft-deletes are CLI-only (`transactions:correct`, `transactions:deactivate`).
- **base-ui**: no `asChild`. Use the component's `render` prop. Popover trigger styling goes on the trigger itself.
- **Pre-push gate**: every `git push` runs `bin/pre-push-checks` (after `bin/setup` has wired the hookpath). Bypass once with `--no-verify`; do not weaken the script — fix the failures.
- **Zod v4, Tailwind v4, React Router v7, Recharts v3** — breaking changes vs. previous majors; check migration guides before bumping.
