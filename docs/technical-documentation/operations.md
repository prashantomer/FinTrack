# Operations

> Rake tasks, cron jobs, releases, recovery recipes. Everything you'd run
> from a shell against a live deployment.

## Rake task index

```
$ bin/rails -T
```

Grouped by purpose:

### User management

| Task | Notes |
|------|-------|
| `users:create` | Interactive. Prompts email / name / password / currency. Pass `DUMMY=1` to mark the new user as dummy. `GENERATE=1` generates a random password. |
| `users:list [KIND=dummy\|real]` | Tabular dump of every user, with type. |
| `users:mark EMAIL=…` | Flip a user to dummy. Pass `REAL=1` to flip back. |
| `users:wipe` | Interactive sector-by-sector wipe of one user's data. Covers every association except `assistant_setting` (the encrypted provider config is preserved). `FAST=1` confirms once and deletes everything. |
| `users:wipe_history` | Targeted variant: wipes only transactional records (transactions, holdings, folios, import batches, txn-related audits). Preserves accounts, term accounts, investments, platform accounts. Resets account balances to 0. |

### Reference data

| Task | Notes |
|------|-------|
| `banks:seed` | Idempotent upsert from `db/seeds/banks.csv`. |
| `platforms:seed` | Broker / MF platform list. |
| `instruments:fetch` | One-time NSE EQ + AMFI scheme catalogue fetch. |
| `instruments:fetch_prices` | Latest close prices → `instruments.last_price` + history. |
| `instruments:backfill_prices` | Range backfill of historical NSE + AMFI prices into `instrument_price_history`. |

### Daily snapshot

| Task | Notes |
|------|-------|
| `daily:pnl` | Runs `Daily::PriceAndPnlSnapshotJob` synchronously (skips Sidekiq). Useful for catch-up or debugging. |
| `daily:status` | Last-run state per `SystemTask`. |

### Balance / audit integrity

| Task | Notes |
|------|-------|
| `accounts:recompute_balances` | Sets `account.balance = sum(signed deltas of active txns)` per account. PPF term-account balances reset the same way; FD balances stay (principal-based). `DRY_RUN=1` reports drift without writing. `USER_ID=<id>` scopes to one user. |
| `audits:backfill` | Wipes synthetic `txn:%` + `carryover` audits per account, then re-emits one audit row per transaction in chronological order. Adds a single `"carryover"` row if there's unexplained drift the txn history can't account for. `DRY_RUN=1` available. |

Typical recovery sequence:

```bash
bin/rails accounts:recompute_balances DRY_RUN=1   # see what's off
bin/rails accounts:recompute_balances             # write the fix
bin/rails audits:backfill                          # rebuild clean timeline
```

### Cleanup

| Task | Notes |
|------|-------|
| `cleanup:preview EMAIL=… [SECTORS=… ...]` | Read-only. Prints before / to_delete / after per sector + a balance_reset projection. Same logic as the UI's preview endpoint. |
| `cleanup:run EMAIL=… [SECTORS=… ...]` | Executes after a typed-DELETE confirmation. `FAST=1` skips the prompt. |

Filters (all optional ENV vars):

- `SECTORS=transactions,investments,…` (defaults to all 10)
- `DATE_FROM=2024-01-01` / `DATE_TO=2024-12-31`
- `SOURCE=manual|imported`
- `ACCOUNT_IDS=1,2`
- `ACTIVE=1|0` (transactions only)
- `TAGS_ANY=salary,rent` (transactions only)
- `RESET_BALANCES=1` (zero account + PPF balances after the wipe)

Sectors covered (FK-safe deletion order): `assistant_messages`,
`import_batches`, `account_audits`, `holdings`, `transactions`,
`investments`, `user_instruments`, `term_accounts`, `accounts`,
`platform_accounts`. `assistant_setting` is intentionally not in the list.

Same services back the UI wizard at `/cleanup` (see
`backend/app/services/cleanup/` and `backend/app/controllers/api/v1/cleanup_controller.rb`).

### Transactions (CLI-only structural changes)

| Task | Notes |
|------|-------|
| `transactions:correct ID=123` | Interactive — update amount / type and reverse the old balance impact in one DB transaction. |
| `transactions:deactivate ID=123` | Soft-delete (`is_active = false`) and reverse balance impact. |

There is **no DELETE endpoint** for transactions. PUT only accepts
`description` + `tags` on `source=manual` rows. Structural corrections are
intentionally CLI-only.

### Releases

| Task | Notes |
|------|-------|
| `release` (alias: `release:wizard`) | Interactive wizard. Reads current `VERSION` + last tag + HEAD, prompts each option with a sensible default, then shells out to `bin/release`. |

The underlying script `bin/release` can also be called directly:

```bash
bin/release [--patch | --minor | --major | --version vX.Y.Z]
            [--ref <sha>]              # release a past commit on main
            [--at YYYY-MM-DD]          # schedule for a future date
            [--draft]                  # create as draft (publish later)
            [--dry-run] [--yes]
```

Guards (all enforced):
- Releases run only from `main` (hard abort).
- Working tree must be clean.
- Local `main` must match `origin/main`.
- `--ref <sha>` requires the commit to be reachable from `main`
  (`git merge-base --is-ancestor`).

`--at <date>` creates a draft release with `Publish-At: <date>` in the body.
The `.github/workflows/release-publisher.yml` workflow runs daily at
04:00 UTC and publishes any drafts whose date matches today.

### AI assistant

| Task | Notes |
|------|-------|
| `assistant:configure` | Interactive — provider (anthropic / openai / ollama), model, api_key. |
| `assistant:status` | Pings the configured provider. |

## Cron / scheduled jobs

`config/sidekiq_cron.yml`:

```yaml
daily_pnl:
  cron: "0 5 * * *"   # 05:00 IST (config.time_zone = Asia/Kolkata)
  class: Daily::PriceAndPnlSnapshotJob
```

The job is also wired with a boot-time catch-up: if the 05:00 tick was
missed (laptop closed, server down), `config/initializers/daily_pnl_catchup.rb`
detects the gap on next boot and enqueues a one-shot run. Same-day re-runs
upsert in place — see `Reports::HoldingSnapshotService#snapshot_all!`.

## Sidekiq queues

```yaml
:queues:
  - [imports, 2]
  - [default, 1]
  - [price_backfill, 1]
```

Concurrency in development is `5`. Web UI mounted at `/sidekiq` (HTTP Basic
Auth via `SIDEKIQ_USERNAME` / `SIDEKIQ_PASSWORD` env vars; without them the
UI is disabled).

If `sidekiq-pauzer` is wired (it is — see `Gemfile`), per-queue pause /
unpause is available via:

```ruby
Sidekiq::Pauzer.pause!("imports")
Sidekiq::Pauzer.paused?("imports")     # => true
Sidekiq::Pauzer.unpause!("imports")
```

And via the Pauzer tab in the Web UI. Jobs continue to enqueue while paused
(growing the queue in Redis) but no worker pulls them until unpaused.

## Database recipes

### Connect via psql

```bash
psql fintrack_db                         # development
RAILS_ENV=test psql fintrack_db_test     # test (rare)
```

### Reset development DB

```bash
bin/rails db:drop db:create db:migrate
bin/rails banks:seed platforms:seed
bin/rails users:create                   # interactive
```

### Nightly backup (manual)

```bash
pg_dump fintrack_db | gzip > "backup-$(date +%F).sql.gz"
```

(Not automated in this repo. If automated backups become important, wire
a cron entry that writes to a rotated directory.)

## Environment

`.env` lives at `backend/.env` (gitignored). Required keys:

```
DATABASE_URL=postgresql://fintrack_user:password@localhost:5432/fintrack_db
REDIS_URL=redis://localhost:6379
SECRET_KEY_BASE=<bin/rails secret>
AR_ENCRYPTION_PRIMARY_KEY=<bin/rails db:encryption:init output>
AR_ENCRYPTION_DETERMINISTIC_KEY=<…>
AR_ENCRYPTION_KEY_DERIVATION_SALT=<…>
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=fintrack-dev
```

Per-user assistant API keys live in `user_assistant_settings.api_key`
(encrypted at rest via AR encryption) — never in env.

## Pre-push gate

`bin/pre-push-checks` is the canonical "is this push safe" script. Runs
in parallel:

| Check          | Tool                                            |
|----------------|-------------------------------------------------|
| rubocop        | `bundle exec rubocop`                           |
| brakeman       | `bundle exec brakeman -q`                       |
| bundler-audit  | `bundle exec bundle-audit check --update`       |
| eslint         | `npm run lint`                                  |
| typecheck      | `npx tsc --noEmit`                              |
| vite build     | `npm run build`                                 |
| rspec          | `bundle exec rspec`                             |

Wired as a git hook via `.githooks/pre-push`; `bin/setup` arms `core.hooksPath`
on fresh clones. `--no-verify` bypasses for emergencies; don't weaken the
script — fix the failures.

---

Last reviewed: 2026-05-11
