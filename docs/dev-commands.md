# FinTrack — Dev Commands

A scenario-grouped reference for everything you'll run while developing, debugging, or operating FinTrack. Stack: Rails 8.1 backend + React 19 frontend + PostgreSQL + Redis + Sidekiq.

---

## Contents

1. [First-time setup](#first-time-setup)
2. [Running the app](#running-the-app)
3. [Users & access](#users--access)
4. [Reference data (banks, platforms, instruments)](#reference-data)
5. [Database & migrations](#database--migrations)
6. [Imports — what works directly](#imports--what-works-directly)
7. [Background jobs (Sidekiq)](#background-jobs-sidekiq)
8. [Daily price fetch + P&L tracking](#daily-price-fetch--pl-tracking)
9. [AI Assistant](#ai-assistant)
10. [Testing](#testing)
11. [Debugging & inspection](#debugging--inspection)
12. [Production build](#production-build)
13. ["I want to..." recipes](#i-want-to-recipes)

---

## First-time setup

Make sure you have the right runtime versions before doing anything else.

| Runtime    | Pin         | Manager |
|------------|-------------|---------|
| Ruby       | `3.3.4`     | rbenv / rvm (`.ruby-version`) |
| Node.js    | `24.x` LTS  | nvm (`.nvmrc`) |
| PostgreSQL | 14+         | brew    |
| Redis      | 7+          | brew    |

```bash
# Activate runtimes (rvm + nvm shown; substitute your manager)
rvm use 3.3.4
source ~/.nvm/nvm.sh && nvm install   # reads .nvmrc

# Backend deps
cd backend && bundle install

# Frontend deps
cd ../frontend && npm install
```

### Postgres + Redis (one-time)

```bash
brew services start postgresql@16
brew services start redis

createdb fintrack_db
createuser fintrack_user --pwprompt
psql -c "GRANT ALL ON DATABASE fintrack_db TO fintrack_user;"
psql -c "ALTER USER fintrack_user CREATEDB;"   # needed for tests
```

### Backend `.env`

Copy `.env.example` → `.env` and fill in:

```dotenv
DATABASE_URL=postgresql://fintrack_user:password@localhost:5432/fintrack_db
REDIS_URL=redis://localhost:6379
SECRET_KEY_BASE=<output of: bin/rails secret>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<bin/rails db:encryption:init>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<same>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<same>
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=fintrack-dev
```

### Schema + seeds

```bash
cd backend
bin/rails db:setup            # create + migrate + (no seed)
bin/rails banks:seed          # bank list (HDFC, ICICI, …)
bin/rails platforms:seed      # broker / MF platform list
bin/rails users:create        # interactive: creates the first user
```

---

## Running the app

The app is **not** a monolith — backend on `:8000`, Vite on `:5173`, Sidekiq as a separate process. Vite proxies `/api` and `/rails` to the backend.

### Backend (Rails + Puma)

```bash
cd backend && bin/rails server                # http://localhost:8000
```

### Frontend (Vite + HMR)

```bash
cd frontend && npm run dev                    # http://localhost:5173
```

### Sidekiq (background jobs)

```bash
cd backend && bundle exec sidekiq             # picks up queues from config/sidekiq.yml
# Web UI:  http://localhost:8000/sidekiq      (HTTP basic auth from .env)
```

### All three at once

If you have `foreman` or `overmind`, a `Procfile.dev` runs all three:

```bash
cd backend && bin/dev                         # convenience wrapper
```

---

## Users & access

There is **no public registration** — users are created from the CLI.

```bash
cd backend

bin/rails users:create                        # interactive
bin/rails users:wipe                          # delete a user + all their data (asks for email)
bin/rails users:list                          # show emails + ids
```

Login is JWT — `POST /api/v1/auth/login`, returns a 7-day token.

---

## Reference data

Banks and platforms are admin-managed; users create their own accounts referencing them.

```bash
# Banks (idempotent upsert by short_name)
bin/rails banks:seed                          # from db/seeds/banks.csv
bin/rails banks:list

# Platforms (Zerodha, Coin, Groww, MFCentral, …)
bin/rails platforms:seed                      # from db/seeds/platforms.csv
bin/rails platforms:list
```

### Instruments (NSE stocks + AMFI mutual funds)

The instrument catalogue is huge (~5k stocks + ~1k MFs). Pull it once, refresh prices daily.

| Task                            | What it does                                                                                              |
|---------------------------------|-----------------------------------------------------------------------------------------------------------|
| `bin/rails instruments:fetch`   | Pulls NSE EQ list + AMFI scheme list. **One-time** (or after big market shifts).                          |
| `bin/rails instruments:fetch_prices` | Pulls today's close prices (NSE bhavcopy + AMFI NAVs) into `instruments.last_price` and `instrument_price_history`. Idempotent — safe to re-run. |
| `DAYS=365 bin/rails instruments:backfill_prices` | Backfills daily price history for **tracked instruments only** over the last `DAYS` days (default 365, max 1825). Fans out via Sidekiq on the `:price_backfill` queue — one job per NSE trading day, one job per 30-day AMFI chunk. Idempotent. |

> The Sidekiq job `Daily::PriceAndPnlSnapshotJob` runs the *daily* fetch at 05:00 IST automatically. Use `instruments:fetch_prices` for ad-hoc same-day refreshes and `instruments:backfill_prices` to populate historical bars (needed before charts on `/instruments/:id` will look interesting on a new install).

---

## Database & migrations

```bash
cd backend

# Generate a migration (datetime-stamped revision IDs — see annotate_rb)
bin/rails g migration AddSomethingToSomething field:type
bin/rails db:migrate                          # forward
bin/rails db:rollback STEP=1                  # back one (project policy: prefer new migrations over rollbacks)

# Reset (DANGEROUS — drops + recreates)
bin/rails db:reset                            # = drop + setup
bin/rails db:reset:reseed                     # custom: + reseed banks/platforms

# Test DB
RAILS_ENV=test bin/rails db:migrate
RAILS_ENV=test bin/rails db:reset

# Demo seed (creates a demo user with realistic transactions/investments/holdings)
bin/rails db:seed:demo                        # idempotent
```

> **Project rule**: write a new migration for any change. Do not edit committed migrations. Sleep ≥1s between generating two migrations to avoid timestamp collisions.

---

## Imports — what works directly

Drop a CSV on the Imports page; the importer auto-detects the format. Supported formats today:

| Format                              | Adapter           | Auto-detected | Notes |
|-------------------------------------|-------------------|---------------|-------|
| Zerodha **Coin** MF Orders          | `Zerodha`         | ✓             | `segment=MF` rows route to "Coin by Zerodha" platform |
| Zerodha **Kite** Tradebook (equity) | `Zerodha`         | ✓             | `segment=EQ` rows route to "Kite by Zerodha" platform |
| FinTrack canonical CSV              | `Default`         | ✓             | Generated by `bin/rails imports:template` or the AI assistant |

For everything else (Groww, Kuvera, bank statements, …), use the AI assistant's `analyse_csv` + `generate_import_csv` flow to convert into FinTrack's canonical schema.

```bash
# Generate a blank template for hand-filling
bin/rails imports:template TYPE=investments  > /tmp/inv.csv
bin/rails imports:template TYPE=transactions > /tmp/txn.csv
bin/rails imports:template TYPE=term_accounts > /tmp/td.csv
```

The importer also **detects duplicates** before writing. The dedupe ladder:

| Type           | Strongest key                          | Fallback                                                 |
|----------------|----------------------------------------|----------------------------------------------------------|
| Investments    | `trade_id`                             | `(order_id, purchase_date)` → structural exact match     |
| Transactions   | `bank_ref` (UTR/IMPS)                  | `(date, amount, type, linked_account)`                   |
| Term Accounts  | `(account_type, account_number)`       | `(parent_account, open_date, amount, account_type)`      |

Re-uploading the same file is safe — duplicates skip with a reference note ("Duplicate of Investment #842 (trade_id 4089431)") and the import status shows the count inline.

---

## Background jobs (Sidekiq)

```bash
# Start
cd backend && bundle exec sidekiq

# Web UI (HTTP basic auth — uses SIDEKIQ_USERNAME / SIDEKIQ_PASSWORD)
open http://localhost:8000/sidekiq

# Queues defined in config/sidekiq.yml (weighted: imports:default:price_backfill = 2:1:1)
#   imports         — CSV import jobs (highest priority)
#   default         — assistant, daily P&L, holding refresh
#   price_backfill  — instruments:backfill_prices fan-out (NSE bhavcopy + AMFI history)
#                     isolated so a 250+ job sweep doesn't squeeze the imports lane

# Cron schedules (sidekiq-cron) — registered at server boot from
# config/sidekiq_cron.yml. Visible in the web UI under "Cron".
```

### From the console

```ruby
# Drain queues right now (handy in dev)
Sidekiq::Queue.new("default").size
Sidekiq::Queue.new("imports").clear

# Inspect cron schedule
Sidekiq::Cron::Job.all.map { |j| [j.name, j.cron, j.last_enqueue_time] }

# Force-run a cron job once
Sidekiq::Cron::Job.find("daily_pnl_snapshot").enque!
```

---

## Daily price fetch + P&L tracking

A scheduled Sidekiq job (`Daily::PriceAndPnlSnapshotJob`, 05:00 IST) does two things:

1. Pulls latest NSE close + AMFI NAVs into `instruments.last_price` and appends a row to `instrument_price_history`.
2. Refreshes every user's holdings and writes one `holding_snapshot` per (holding × date) — capturing market price, units, cost basis, current value, realized + unrealized P&L.

Both writes are upserts: re-running for the same date overwrites the price/stats and bumps `updated_at`, leaving `created_at` as the original capture time.

If the app was down at 05:00, a boot initializer enqueues the job once on the next start so a missed day doesn't stay missed.

### CLI

```bash
bin/rails daily:pnl       # run synchronously, foreground (good for debugging)
bin/rails daily:status    # show last successful run for every scheduled task
```

### Console snippets

```ruby
# Did the daily job actually run today?
SystemTask.find_by(name: "daily_pnl")
# => last_completed_date / last_status / last_error

# How many price points captured today?
InstrumentPriceHistory.where(price_date: Date.current).group(:source).count
# => { "nse_bhavcopy" => 1980, "amfi_navall" => 1124 }

# Price history for one instrument (by ticker)
inst = Instrument.find_by("UPPER(ticker_symbol) = ?", "INFY")
InstrumentPriceHistory.for_instrument(inst.id).latest_first.limit(20)
  .pluck(:price_date, :price, :source)

# Or by ISIN (works for MFs)
inst = Instrument.find_by(isin: "INF209K01YQ7")
InstrumentPriceHistory.for_instrument(inst.id).latest_first.limit(20)

# Chart-ready time series for one instrument
InstrumentPriceHistory.for_instrument(inst.id)
  .where(price_date: 30.days.ago.to_date..Date.current)
  .order(:price_date)
  .pluck(:price_date, :price)

# Per-platform daily P&L roll-up
HoldingSnapshot
  .where(snapshot_date: Date.current)
  .group(:platform_account_id)
  .sum(:unrealized_gain)

# Re-run for a back-dated date
Daily::PriceAndPnlSnapshotJob.perform_now("2026-05-06")

# Just fetch prices, skip snapshot
Instruments::PriceFetchService.call

# Just snapshot a single user
Reports::HoldingSnapshotService.new(User.first, date: Date.current).call
```

### Backfilling historical prices (`instruments:backfill_prices`)

The daily fetch only writes today's close. To populate a year (or more) of history — e.g. before showing the Instrument Profile price chart on a fresh install — fan out via Sidekiq:

```bash
# Smoke first — confirms both NSE and AMFI parsers actually work end-to-end
DAYS=5 bin/rails instruments:backfill_prices

# Full year. ~252 NSE jobs (one per trading day) + ~13 AMFI jobs (30-day chunks).
# Default Sidekiq concurrency 5 → ~1-3 minutes for ~100 tracked instruments.
DAYS=365 bin/rails instruments:backfill_prices

# Watch progress
open http://localhost:8000/sidekiq          # web UI, filter on price_backfill queue
tail -f logs/instrument_fetch.log
```

Notes:
- **Tracked only.** The task scopes to instruments in `user_instruments` — untracked catalogue rows are skipped. Adjust by editing the rake task if you ever need a fuller backfill.
- **Idempotent.** Hits the `(instrument_id, price_date)` unique index. Re-running fills gaps without duplicating rows.
- **Holidays.** NSE bhavcopy 404s for non-trading days; the job logs and silently no-ops for those dates. AMFI returns sparse data for debt/hybrid funds — expected.
- **Sources.** Backfill writes use `source: "nse_bhavcopy"` / `"amfi_navhistory"`. The daily fetch writes `"nse_bhavcopy"` / `"amfi_navall"` — distinct strings let you tell at a glance which path produced any given row.
- **Verifying coverage** (after the run):

```ruby
# Per-instrument coverage histogram in the last 365 days, tracked only
tracked = UserInstrument.distinct.pluck(:instrument_id)
hist    = InstrumentPriceHistory
            .where(instrument_id: tracked, price_date: 365.days.ago..)
            .group(:instrument_id).count
hist.values.tally { |c| c >= 240 ? "full"    :
                        c >= 150 ? "partial" :
                        c >  0   ? "sparse"  : "missing" }
```

---

## AI Assistant

Per-user provider config (Anthropic, OpenAI, Ollama). Set up once per user; lives in `user_assistant_settings` with the API key encrypted at rest.

```bash
bin/rails assistant:configure   # interactive: provider, model, key, base_url
bin/rails assistant:status      # ping the configured provider
```

From the UI: **/assistant** → settings panel → switch providers without losing chat history.

---

## Pre-push checks

A single script runs every quality gate before code reaches the remote — backend specs, Rubocop, Brakeman, bundler-audit, frontend ESLint, typecheck, and production build. Independent checks run in parallel; the summary table at the end shows pass/fail per check with log paths for failures.

```bash
bin/pre-push-checks            # full sweep (~30–60 s)
bin/pre-push-checks --quick    # skip the slow ones (Brakeman + Vite build)
```

### Wire it as a git hook (one-time per clone)

```bash
git config core.hooksPath .githooks
```

After that, every `git push` runs the checks first and refuses the push on failure. Bypass for a single push: `git push --no-verify` (use sparingly).

### Or invoke via Claude Code

`.claude/agents/pre-push.md` is registered — `/agents pre-push` runs the same checks and reports findings inline.

---

## Testing

### Backend (RSpec)

```bash
cd backend

bundle exec rspec                                  # full suite
bundle exec rspec spec/services                    # one folder
bundle exec rspec spec/models/user_spec.rb         # one file
bundle exec rspec spec/models/user_spec.rb:42      # one line / one example
bundle exec rspec --tag focus                      # tagged examples only
bundle exec rspec --fail-fast                      # stop at first failure
bundle exec rspec --format documentation           # nested describe/it tree
```

### Frontend

```bash
cd frontend

npx tsc --noEmit                                   # typecheck
npx eslint src/                                    # lint
npx eslint src/pages/AssistantPage.tsx             # lint one file
npm run build                                      # production build (catches everything)
```

### Linting & formatting

```bash
cd backend  && bundle exec rubocop                 # backend lint
cd frontend && npm run lint                        # ESLint
```

---

## Debugging & inspection

### Logs

| Path                                       | What's there                                    |
|--------------------------------------------|-------------------------------------------------|
| `backend/log/development.log`              | Rails request log                               |
| `backend/log/sidekiq.log`                  | Sidekiq worker output                           |
| `logs/instrument_fetch.log`                | NSE/AMFI fetch service (via the rake task)      |

Tail multiple at once:

```bash
tail -f backend/log/development.log backend/log/sidekiq.log
```

### Rails console

```bash
cd backend && bin/rails console                    # full env
cd backend && bin/rails console --sandbox          # auto-rolls back on exit
RAILS_ENV=test bin/rails console                   # test env (handy for repro)
```

Common one-liners:

```ruby
User.last                                          # most recent user
User.find_by(email: "you@example.com")
Investment.where(user: User.first).count
Holding.for_user(User.first).where(is_closed: false).count
ImportBatch.last.import_records.where(status: "skipped").count
Audited::Audit.where(auditable_type: "Investment").last(5)
```

### DB shell

```bash
bin/rails dbconsole                                # psql with the dev URL
psql fintrack_db                                   # direct
```

---

## Production build

```bash
# Backend
cd backend
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails server

# Frontend
cd frontend
npm run build                                      # outputs frontend/dist/
```

Production deployment serves the SPA via Nginx (or a CDN) with `/api` and `/rails` proxied to the Rails app on port 8000.

---

## "I want to..." recipes

Quick copy-paste solutions for things you'll do often.

### "I want to start a clean dev environment from scratch"

```bash
cd backend
bin/rails db:reset
bin/rails banks:seed && bin/rails platforms:seed
bin/rails users:create                  # email + password
bin/rails db:seed:demo                  # optional demo data
```

### "I want to test a CSV import locally"

```bash
# Get the canonical template
bin/rails imports:template TYPE=investments > /tmp/inv.csv
# Drop a Zerodha export directly:
cp ~/Downloads/coin-mf-orders.csv /tmp/test.csv
# Upload via the /imports page or:
curl -F file=@/tmp/test.csv -F import_type=investments \
     -H "Authorization: Bearer $TOKEN" \
     http://localhost:8000/api/v1/imports
```

### "I want to inspect today's price fetch"

```ruby
# Console
SystemTask.find_by(name: "daily_pnl")                              # did it run?
InstrumentPriceHistory.where(price_date: Date.current).count       # how many points?
InstrumentPriceHistory.where("price_date = ? AND price IS NULL", Date.current)
  .count                                                            # any failures?
```

### "I want to backfill a missed day"

```bash
bin/rails runner 'Daily::PriceAndPnlSnapshotJob.perform_now("2026-05-06")'
```

### "I want to backfill a year of price history (e.g. on a fresh install)"

```bash
# Make sure Sidekiq is running first
bundle exec sidekiq                         # in another terminal

DAYS=5   bin/rails instruments:backfill_prices   # smoke — confirms the parsers work
DAYS=365 bin/rails instruments:backfill_prices   # full year, ~250 jobs on :price_backfill
tail -f logs/instrument_fetch.log
```

Tracked instruments only; idempotent; safe to re-run to fill any gaps. See the [backfill section](#backfilling-historical-prices-instrumentsbackfill_prices) for verification queries.

### "I want to wipe a test user's data without nuking the DB"

```bash
bin/rails users:wipe       # interactive — deletes user + cascades to investments, holdings, snapshots, etc.
```

### "I want to verify the cron schedule is loaded"

```bash
bundle exec sidekiq        # in one terminal
# Then in console:
bin/rails runner 'pp Sidekiq::Cron::Job.all.map { |j| [j.name, j.cron, j.last_enqueue_time] }'
# OR open the web UI: http://localhost:8000/sidekiq → Cron tab
```

### "I want to run only the specs I just changed"

```bash
cd backend
bundle exec rspec $(git diff --name-only HEAD | grep _spec.rb)
```

### "I want to see why an import row failed or was deduped"

```ruby
batch = ImportBatch.last
batch.import_records.where(status: "error").pluck(:row_index, :notes)
batch.import_records.where(status: "skipped").pluck(:row_index, :notes)
# Notes carry references like "Duplicate of Investment #842 (trade_id 4089431)"
```

### "I want to switch the AI assistant provider mid-session"

UI: `/assistant` → settings panel → pick provider → paste key → Save.
CLI: `bin/rails assistant:configure` (works for the first user; for others use the UI).

### "I want to confirm the timezone is right"

```ruby
# Console
Time.zone.name              # => "Asia/Kolkata"
Time.current                # IST
Date.current                # IST date
```

### "I want to drop into a DB transaction and roll back changes after"

```ruby
ActiveRecord::Base.transaction do
  user = User.first
  user.investments.destroy_all
  Holdings::RefreshService.refresh_all_for(user)
  raise ActiveRecord::Rollback   # cancels everything
end
```

---

## Quick links

- **Architecture**: [backend-architecture.md](./backend-architecture.md), [frontend-architecture.md](./frontend-architecture.md)
- **ERD**: [erd.md](./erd.md)
- **Roadmap**: [development-roadmap.md](./development-roadmap.md)
- **Sidekiq UI**: http://localhost:8000/sidekiq (after login)
- **API docs**: http://localhost:8000/api-docs (Rswag UI)
- **App**: http://localhost:5173 (dev) · http://localhost:8000 (prod build)
