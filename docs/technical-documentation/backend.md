# Backend patterns

> Conventions you'll encounter in every backend change. Most of them are
> light — Rails-default plus a few opinionated choices.

## Controllers

```
app/controllers/
├── application_controller.rb
└── api/v1/
    ├── accounts_controller.rb
    ├── auth_controller.rb
    ├── cleanup_controller.rb
    ├── imports_controller.rb
    ├── instruments_controller.rb
    ├── transactions_controller.rb
    └── ...
```

`ApplicationController` includes `Authenticatable` (concern) which runs
`before_action :authenticate_user!` and exposes `current_user` resolved
from the `Authorization: Bearer <jwt>` header. JWT auth is opt-out per
endpoint via `skip_before_action :authenticate_user!`.

### Anatomy

```ruby
def index
  # Permit + translate params
  filter = Investments::Filter.from_params(params)
  # Delegate to a service
  result = Investments::QueryService.new(current_user, filter).call
  # Render with the wrapper helper
  render_success(
    data:      result[:items],
    meta_data: { total: result[:total], page: result[:page], page_size: result[:page_size] }
  )
end
```

Render helpers (defined in `ApplicationController`):
- `render_success(data:, meta_data: nil, status: :ok)`
- `render_created(data:, meta_data: nil)` — `:created` + Location header
- `render_error(message:, status: :unprocessable_entity, errors: nil)`

Every JSON response is wrapped as `{ data: ..., meta_data: ... }` (or
`{ errors: { message: ... } }`). The frontend client unwraps `data` /
`meta_data` consistently.

### Serializers

Plain Ruby, no jbuilder. Pattern:

```ruby
class TransactionSerializer < BaseSerializer
  def self.attributes(r)
    { id: r.id, amount: r.amount, ... }
  end
end
```

`BaseSerializer` provides `.one(record)` and `.many(records)`, both producing
plain hashes the controller can hand to `render_success`. To add a field:
edit the serializer file and the matching `frontend/src/types/index.ts`
interface in the same commit.

## Services

Where business logic lives. Three rough sub-patterns:

### 1. Single-shot action services

```ruby
class Accounts::AdjustBalanceService
  class Error < StandardError; end

  def initialize(user, account, target_balance:, date:, description:)
    @user, @account = user, account
    # ...
  end

  def call
    # validations → side effects → return value
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.message
  end
end
```

Naming: `Domain::VerbNounService` (`AdjustBalanceService`, `RefreshService`,
`CloseService`). Public surface is `new(...).call`. Errors are surfaced via
a per-service `Error` class for the controller to catch and `render_error`.

### 2. Query services with filters

```ruby
class Investments::Filter < ::Queries::FilterBase
  attribute :investment_type, array: true
  attribute :trade_type, :source
  attribute :date_from, :date_to
  attribute :sort_by, :sort_dir

  def apply(scope)
    scope = with_in(scope, "investments.investment_type", investment_type)
    scope = with_eq(scope, "investments.trade_type", trade_type)
    # ...
  end
end

class Investments::QueryService
  def initialize(user, filter)
    @user, @filter = user, filter
  end

  def call
    base  = @user.investments.unscope(:order).includes(user_instrument: :instrument)
    scope = @filter.apply(base)
    { items: scope.reorder(@filter.order_clause).offset(@filter.offset).limit(@filter.page_size),
      total: scope.count, page: @filter.page, page_size: @filter.page_size }
  end
end
```

`Queries::FilterBase` (in `app/services/queries/filter_base.rb`) handles:
- `.from_params(params)` — declares + permits the attribute list.
- `attribute :name` / `attribute :name, array: true` — DSL for declaring fields.
- Built-in pagination (`page`, `page_size`, `offset`, `cursor`).
- Scope helpers: `with_in`, `with_eq`, `with_range`, `with_ilike_any` (parameterised search across multiple columns).

Whenever a new filter or sort dimension is needed, edit the `Filter` subclass
and adjust `apply` (or add an `order_clause` method). The controller stays
3 lines.

### 3. Pure-function helpers

`Holdings::PositionCalculator.call(lots, current_price:, investment_type:)`
is the FIFO walk. No state, no DB writes, no callbacks — just `lots → stats`.
Both `Holdings::RefreshService` (cache write) and
`Reports::PortfolioService` (live snapshot) consume it.

When a calculation is consumed by more than one caller, extract it to a
pure-function service. Don't duplicate.

## Background jobs

Sidekiq queues (declared in `config/sidekiq.yml`):

| Queue            | Used by                                             |
|------------------|-----------------------------------------------------|
| `imports`        | `Imports::Process{Investment,Transaction,TermAccount}CsvJob` |
| `default`        | `Holdings::RefreshJob`, ad-hoc jobs                 |
| `price_backfill` | `Instruments::BackfillNsePricesJob`, `BackfillAmfiNavsJob` |

Scheduled jobs (`config/sidekiq_cron.yml`):

| Job | When |
|---|---|
| `Daily::PriceAndPnlSnapshotJob` | 05:00 IST daily |

Boot-time catch-up: `config/initializers/daily_pnl_catchup.rb` detects a
missed 05:00 tick on the next boot and enqueues a one-shot run. Use
`bin/rails daily:pnl` to run synchronously, `bin/rails daily:status` to see
the last-run state.

## Authentication

JWT, HS256, 7-day expiry. Encoded with `Rails.application.secret_key_base`.

```ruby
# app/services/json_web_token.rb (paraphrased)
JsonWebToken.encode(user_id: user.id)
JsonWebToken.decode(token)  # → { user_id: ..., exp: ... }
```

`Authenticatable` concern (`app/controllers/concerns/authenticatable.rb`):
- Reads `Authorization: Bearer <token>`.
- Returns 401 on missing/invalid/expired.
- Memoises `current_user` per request.

Passwords are `has_secure_password` (bcrypt). No public registration; users
created via `bin/rails users:create`.

## Audit & encryption

- `audited` gem — see [`audit-and-balance.md`](./audit-and-balance.md).
- Active Record encryption — used on `UserAssistantSetting#api_key` so an
  API key is never readable in DB dumps. Keys in env:
  `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`,
  `AR_ENCRYPTION_KEY_DERIVATION_SALT`. Generate via
  `bin/rails db:encryption:init`.

## Migrations

- Datetime-stamped (`20260511065709_*`). Sleep ≥1 s between generating two
  migrations.
- No downgrades — every change is a new forward migration. If you need to
  drop a column, write a new migration that does it; don't edit the original.
- Annotaterb keeps schema comments at the top of each model file in sync.
  Run `bin/rails db:migrate` and the model files auto-update.

## Testing

RSpec. Conventions:

- `spec/factories/*.rb` — FactoryBot factories per model. Keep them minimal;
  add traits for variation.
- `spec/services/<domain>/...` — service specs. Mirror `app/services/<domain>/`.
- `spec/models/...` — model specs (validations, scopes, callbacks).
- `spec/jobs/...` — Sidekiq job specs.
- `spec/requests/api/v1/...` — request specs for integration coverage.

Run subsets via path arg or `--example` for a string match:

```bash
bundle exec rspec spec/services/holdings/
bundle exec rspec spec/services/holdings/position_calculator_spec.rb
bundle exec rspec --example "FIFO"
```

Test DB needs the user role to have `CREATEDB` (used by `db:test:prepare`):

```sql
ALTER USER fintrack_user CREATEDB;
```

## Performance & pagination

Default `page_size` is 30 (transactions, investments). Hard cap: 200
(`FilterBase::MAX_PAGE_SIZE`). Pagination is offset-based (page/page_size →
cursor/limit translated server-side). Cursor-based pagination is supported
by `Transactions::QueryService` (returns `next_cursor` in `meta_data`) but
the UI currently uses page-based.

Indexes worth knowing:

- `transactions(date, id)` — drives the default sort.
- `transactions(linked_account_type, linked_account_id)` — account-filter.
- `instrument_price_history(instrument_id, price_date)` — daily snapshot read path.
- `import_batches(user_id, import_number)` UNIQUE — guarantees a clean sequence.

---

Last reviewed: 2026-05-11
