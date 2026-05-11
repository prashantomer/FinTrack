# Architecture

## Stack

| Layer        | Choice                                                  |
|--------------|----------------------------------------------------------|
| Backend      | Rails 8.1, Ruby 3.3.4, Puma                              |
| Database     | PostgreSQL 14+ (uses `JSONB`, array columns, window fns) |
| Background   | Sidekiq 7 on Redis 7                                     |
| Auth         | JWT (HS256, 7-day expiry) via `jwt` gem; `bcrypt` for passwords |
| Audit        | `audited` gem on `Account#balance` and `TermAccount#balance` |
| Encryption   | Active Record encryption (`UserAssistantSetting#api_key`) |
| File storage | Active Storage (local disk by default; used by `ImportBatch#file`) |
| Frontend     | React 19, TypeScript 5, Vite 8                           |
| UI library   | base-ui (not Radix; see "Gotchas") + Tailwind v4 + shadcn-style wrappers |
| State        | TanStack Query v5 (server) + minimal React state (client) |
| Charts       | Recharts 3                                                |

## Repo layout

```
FinTrack/
├── backend/                # Rails 8.1 API
│   ├── app/
│   │   ├── controllers/api/v1/   # Thin controllers; delegate to services
│   │   ├── jobs/                 # Sidekiq jobs (Daily, Holdings, Imports)
│   │   ├── models/               # AR models; annotaterb keeps schemas in comments
│   │   ├── serializers/          # Plain Ruby, no jbuilder
│   │   └── services/             # Business logic — the heart of the app
│   │       ├── accounts/         # CloseService, AdjustBalanceService
│   │       ├── assistants/       # Conversation, ToolRegistry, providers
│   │       ├── cleanup/          # ScopeBuilder + PreviewService + ExecuteService
│   │       ├── holdings/         # PositionCalculator (FIFO), RefreshService
│   │       ├── imports/          # Adapters, row services, workbook reader
│   │       ├── instruments/      # PriceFetchService, ProfileService, ProfileGate
│   │       ├── investments/      # Filter (FilterBase subclass), QueryService
│   │       ├── queries/          # FilterBase — shared filter machinery
│   │       ├── reports/          # PortfolioService, HoldingSnapshotService
│   │       ├── term_accounts/    # CreateService, CloseService
│   │       └── transactions/     # CreateService, QueryService
│   ├── config/
│   │   ├── routes.rb
│   │   ├── sidekiq.yml           # Queue names + concurrency
│   │   ├── sidekiq_cron.yml      # Scheduled jobs (daily snapshot)
│   │   └── initializers/
│   │       └── daily_pnl_catchup.rb   # Boot-time catch-up if cron missed a tick
│   ├── db/migrate/               # Datetime-stamped migrations, no downgrades
│   ├── lib/tasks/                # Rake tasks (see operations.md)
│   └── spec/                     # RSpec
├── frontend/src/
│   ├── api/                      # Per-domain Axios call functions
│   ├── components/               # ui/ (shadcn+base-ui), accounts/, imports/, etc.
│   ├── context/                  # AuthContext only
│   ├── hooks/                    # TanStack Query hooks per domain
│   ├── lib/                      # finance.ts, errors.ts, errorReporter.ts
│   ├── pages/                    # One file per route
│   └── types/index.ts            # All shared TS interfaces, mirrors backend serializers
├── bin/                          # release, pre-push-checks, dev-setup
├── docs/                         # This folder lives here
└── VERSION                       # Canonical version source (consumed by bin/release)
```

## Request lifecycle (read-path example: `GET /api/v1/transactions`)

```
Browser → /api/v1/transactions?page=2&page_size=30&sort_by=date&sort_dir=desc
   │
   ▼
┌────────────────────────────────────────────────────────────┐
│ Rails router (config/routes.rb)                             │
│   resources :transactions, only: [:index, :create, :update] │
└────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────┐
│ ApplicationController                                        │
│   before_action :authenticate_user! (Authenticatable concern)│
│     → reads `Authorization: Bearer <jwt>`                    │
│     → sets `Current.user = current_user`                     │
└────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────┐
│ Api::V1::TransactionsController#index                       │
│   query_params  → permits + translates page/page_size       │
│                   to cursor/limit for the service           │
│   Transactions::QueryService.new(current_user, params).call │
└────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────┐
│ Transactions::QueryService                                  │
│   - applies filters (date, type, source, account, tags)     │
│   - applies sort (date | account, asc/desc)                 │
│   - paginates via offset/limit                              │
│   - returns { items:, total:, next_cursor: }                │
└────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────┐
│ Controller's render_success                                  │
│   serialises items via TransactionSerializer.many           │
│   embeds { data:, meta_data: { total, next_cursor } }       │
└────────────────────────────────────────────────────────────┘
   │
   ▼ JSON
Frontend → useTransactions hook → TanStack Query → TransactionsPage
```

Write-path (`POST /api/v1/transactions`) follows the same shape but ends in
a service (`Transactions::CreateService`) that calls `Transaction.create!`,
which triggers `after_create :apply_balance_delta` — see
[`audit-and-balance.md`](./audit-and-balance.md).

## Architectural boundaries that matter

### Thin controllers, fat services

Controllers do four things only: authenticate, parse params, call a service,
serialise the result. Almost every controller method is 1–10 lines. Anything
that needs to think — filter logic, balance math, FIFO, import dispatch —
lives in `app/services/`.

### Models stay narrow

Models declare AR associations, scopes, validations, enums, and 1–2 instance
methods that are intrinsic to the row (e.g. `Transaction#credit?`). They do
**not** know about queries, presenters, or cross-table operations. Anything
multi-row, multi-table, or with side effects sits in a service.

The two exceptions where models do hold logic:

- `Transaction#apply_balance_delta` (after_create) and `#reverse_balance_delta`
  (before_destroy) — they must run automatically on every persistence path
  to keep `accounts.balance` in lock-step with the transaction ledger.
- `ImportBatch#set_import_version` and `#set_import_number` (before_create) —
  monotonic counters that need a hook to populate before the row hits disk.

### `Current` for cross-cutting flags

`app/models/current.rb` is an `ActiveSupport::CurrentAttributes` subclass
that carries per-request state too crosscutting for thread-locals:

- `Current.skip_holding_refresh` — bulk loaders set this to suppress the
  per-Investment `Holdings::RefreshJob` enqueue and run a single sweep at
  the end.

That's the only flag today. Resist adding more — `Current` is global state
disguised as DI, easy to abuse.

### `Audited.audit_class.as_user` for who-did-what

The audited gem records `user_id` from a thread-local set via
`Audited.audit_class.as_user(user) { ... }`. Every balance-mutating path
wraps its `update!` in this block so audit rows have a real user attribution.

## Frontend → backend boundary

Single Axios instance (`frontend/src/api/client.ts`) with `baseURL: "/api/v1"`.
Request interceptor injects `Authorization: Bearer <jwt>` from localStorage;
response interceptor clears the token and redirects to `/login` on 401.

The Vite dev server proxies `/api`, `/rails` (Active Storage signed URLs),
and `/sidekiq` to the Rails server at `http://localhost:8000`. In production
the React build is served as static assets and the Rails monolith handles
both API and asset delivery (see `docs/dev-commands.md` for the prod
serving notes).

## Pre-push gate

`bin/pre-push-checks` runs in parallel: rubocop, brakeman, bundler-audit,
eslint, tsc, vite build, rspec. Wired as a git hook via `.githooks/pre-push`;
`bin/setup` arms `core.hooksPath`. The gate runs on every `git push`. Bypass
once with `--no-verify` for emergencies; do not weaken the script.

## Gotchas

- **base-ui is not Radix.** No `asChild` prop. Style triggers directly, or use
  the `render` prop pattern. The `Button` wrapper uses `render`; passing
  `asChild` will nest elements and break layout. See user memory file
  `feedback_baseui_aschild.md`.
- **Migrations are datetime-stamped, no downgrades.** Sleep ≥1 second between
  generating two migrations to avoid timestamp collisions.
- **Time zone is `Asia/Kolkata`.** Cron schedules and `Date.current` use IST.
  Do not change this without auditing every report and snapshot.
- **`delete_all` skips callbacks.** This is by design for bulk operations
  (cleanup, import batches), but means any new "must run on every destroy"
  logic needs to use `destroy_all` or a database-level constraint.

---

Last reviewed: 2026-05-11
