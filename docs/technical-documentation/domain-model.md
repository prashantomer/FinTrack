# Domain Model

> The ten entities that matter. Every other model is either a child of one of
> these or reference data (banks, platforms, instruments). The annotated
> schema comments at the top of each model file are the canonical column
> list — this doc explains relationships and *why* fields exist.

## Entity map

```
                          ┌──────────┐
                          │   User   │  (is_dummy, is_active, currency_*)
                          └────┬─────┘
        ┌────────────┬────────┼─────────┬────────────┬──────────────┐
        │            │        │         │            │              │
        ▼            ▼        ▼         ▼            ▼              ▼
   Accounts    TermAccounts  Platform  UserInstr-  Investments   ImportBatches
   (bank)      (FD / PPF)    Accounts  uments      (stock / MF   (CSV / XLS
                             (Zerodha   (watchlist) lot)         uploads)
                              etc.)         │           │
        │            │                       │           ▼            │
        │            │                       │       Holdings         │
        │            │                       │       (cached agg:     │
        │            │                       │        Folio MF,       │
        │            │                       │        EquityHolding)  │
        │            │                       │                         │
        └────┬───────┘                       │                         │
             ▼                                │                         ▼
       Transactions ◄──── instrument_id ──────┘                  ImportRecords
       (credit /                                                  (per-row outcome)
        debit, polymorphic linked_account)                              │
                                                                         ▼
                                                                  Importable
                                                                  (polymorphic →
                                                                   Transaction /
                                                                   Investment /
                                                                   TermAccount)

                          ┌──────────────────┐
                          │ Audited::Audit   │ (gem-managed table)
                          │   auditable_type │   "Account" / "TermAccount"
                          │   auditable_id   │   ↑ the row whose balance changed
                          │   audited_changes│   { "balance": [old, new] }
                          │   user_id        │
                          │   comment        │   "txn:<id>" | "close:..." | "revert:..."
                          └──────────────────┘
```

## Per-entity notes

### `User`
`backend/app/models/user.rb`

- One per real or demo user. No public registration; created via `bin/rails users:create`.
- `is_active` (login enabled), `is_superuser` (reserved for future admin UI),
  `is_dummy` (excludes from real-user counts; gates destructive seed tasks).
- Owns: `accounts`, `term_accounts`, `platform_accounts`, `user_instruments`,
  `investments`, `transactions`, `holdings`, `import_batches`,
  `assistant_messages`, `assistant_setting` (singleton — provider + encrypted API key).
- See [`operations.md`](./operations.md) for the `is_dummy` lifecycle (`users:mark`, seed-task guards).

### `Account`
`backend/app/models/account.rb`

- Bank account. `account_type` ∈ {savings, current, salary, nre, nro}.
- `balance: decimal(14, 2)` — running total derived from `Transaction`s linked here.
  **Mutated only via `Transaction#apply_balance_delta`** (or, rarely, via
  `Account#credit!` / `#debit!` which take a `source:` kwarg to stamp the audit).
- `open_date` is NOT NULL and immutable in spirit (validated on create; no
  controller path edits it). Transactions linked to an account must have
  `date >= open_date`.
- Audited on `balance` only — every balance change produces one audit row
  with `comment` tying it to the source event.

### `TermAccount`
`backend/app/models/term_account.rb`

- STI by behaviour, single table. `account_type` ∈ {fd, ppf}. Each TermAccount
  has a `parent_account` (an Account — the savings account it was funded
  from).
- FD: `balance = principal × (1 + rate × tenure_days / 365 / 100)` at maturity,
  not derived from transactions. **FDs intentionally skip the
  `apply_balance_delta` callback** — see [`audit-and-balance.md`](./audit-and-balance.md).
- PPF: balance accumulates from `Transaction`s linked with `linked_account_type = "TermAccount"`.
- Audited on `balance`. `close!` stamps `audit_comment = "close:term_account_<id>"`.

### `Transaction`
`backend/app/models/transaction.rb`

- The ledger row. `transaction_type` ∈ {credit, debit}, `amount > 0`.
- `linked_account` is a **polymorphic association**: `linked_account_type` is
  `"Account"` or `"TermAccount"`, `linked_account_id` the FK. No DB FK
  constraint — keeps the polymorphism flexible.
- `source` ∈ {manual, imported}. Manual rows accept narrow PUTs
  (description + tags only); imported rows are frozen. No DELETE endpoint;
  destruction goes through rake tasks or `Cleanup::ExecuteService`.
- `tags: text[]` — array column, free-form labels. Reserved values used by
  the app: `"adjustment"` (created by `Accounts::AdjustBalanceService`).
- `bank_ref: varchar(100)` — UTR / IMPS / synthetic dedup key.
- `is_active: boolean` — soft-delete flag. `transactions:deactivate` rake
  task flips it and reverses balance.
- Callbacks:
  - `after_create :apply_balance_delta` — credits/debits the linked account.
  - `before_destroy :reverse_balance_delta` — inverse of apply, so destroy
    is safe (added in PR #12).

### `Investment`
`backend/app/models/investment.rb`

- Individual buy/sell lot. `investment_type` ∈ {stock, mutual_fund},
  `trade_type` ∈ {buy, sell}. `quantity` for stocks, `units` for MF.
- References `user_instrument` (and through it the `Instrument` catalogue
  row) and `platform_account` (the broker / MF platform account the trade
  ran through).
- `source` enum mirrors Transaction's. Imports are frozen; manual rows
  accept a narrow PUT (`notes` only).
- `after_save_commit :enqueue_holding_refresh` — fires
  `Holdings::RefreshJob` per write. Bulk loaders set
  `Current.skip_holding_refresh = true` and enqueue a single sweep.
- FIFO math + LT/ST split lives in `Holdings::PositionCalculator` — pure
  function called by both `Holdings::RefreshService` (cache write) and
  `Reports::PortfolioService` (live snapshot).

### `Holding`
`backend/app/models/holding.rb` (+ `Folio`, `EquityHolding`)

- Aggregated cache of investments per `(user_instrument × platform_account)`.
  Single table, STI by `type` column: `Folio` (MF), `EquityHolding` (stock).
- Fields: `total_units`, `avg_buy_price`, `total_invested`, `current_value`,
  `unrealized_gain`, `realized_gain`, `long_term_units`, `short_term_units`,
  `is_closed`, `last_calculated_at`.
- Folios additionally carry `folio_number` (with a `"(unset)"` placeholder
  fallback so the presence validation passes on imports that didn't supply one).
- Rebuilt by `Holdings::RefreshService` after every Investment write.

### `UserInstrument`
`backend/app/models/user_instrument.rb`

- "User has added this instrument to their book" — equivalent to a watchlist
  entry, also implicit when the user holds investments in that instrument.
- Unique on `(user_id, instrument_id)`.
- Drives `Instruments::ProfileGate`: a user can view the profile page of any
  instrument they have a `user_instrument` for (or hold investments in), plus
  any with `profile_enabled = true` when the global mode is `per_instrument`.

### `Instrument`
`backend/app/models/instrument.rb`

- Global catalogue (reference data). Stocks (NSE EQ) and mutual funds
  (AMFI scheme catalogue). Seeded via `bin/rails instruments:fetch`.
- `last_price`, `last_price_at` — refreshed by `Daily::PriceAndPnlSnapshotJob`.
- `profile_enabled` — opt-in flag for the per-instrument profile page when
  the global mode is `per_instrument`.

### `ImportBatch`
`backend/app/models/import_batch.rb`

- One row per CSV/XLS upload. `import_type` ∈ {investments, transactions, term_accounts}.
- `import_version` — per-(user, type) sequence ("transactions v3").
- `import_number` — per-user global sequence ("import #42"), what the UI shows.
- `status` ∈ {pending, processing, completed, failed, needs_reconciliation}.
  The last value pauses the batch for user input — see [`imports.md`](./imports.md).
- `on_balance_mismatch` ∈ {ask, adjust, fail} — user policy when source-file
  balance disagrees with computed account balance post-import.
- `expected_balance` — captured from the last row of the source file when the
  adapter exposes a running balance (ICICI's `Balance(INR)` column).
- `linked_account_type / linked_account_id` — set when the source format
  doesn't carry per-row account info (xls bank statements).
- `has_one_attached :file` — the source CSV/XLS via Active Storage.
- `has_many :import_records, dependent: :destroy` — per-row outcome.

### `ImportRecord`
`backend/app/models/import_record.rb`

- One per row processed during an import. `status` ∈ {ok, error, skipped}.
- `importable` is a polymorphic association pointing at the created
  Transaction / Investment / TermAccount (for `ok` rows) or the existing
  duplicate (for `skipped`).
- `notes` — human-readable explanation: the linked-account name on success,
  the matched record reference on a duplicate, or the error message on failure.

### `Audited::Audit` (gem-provided)

- The audit trail. We only audit `balance` on `Account` and `TermAccount`.
- `auditable_type` ∈ {"Account", "TermAccount"}; `auditable_id` is the row.
- `audited_changes` is `{"balance" => [old, new]}` for updates, `{"balance" => 0.0}` for create rows.
- `comment` is structured-free-text used as the source-of-change reference:
  - `"txn:<id>"` — caused by a Transaction (default for `apply_balance_delta`).
  - `"close:term_account_<id>"` — TermAccount#close! zeroed the balance.
  - `"revert:txn_<id>"` — Transaction#destroy reversed an earlier delta.
  - `"carryover"` — synthesized by `audits:backfill` to absorb pre-fix drift.
- Two controllers (`accounts#audit_logs`, `term_accounts#audit_logs`) resolve
  the `txn:<id>` comments back to the transaction and embed it in the
  response so the Balance History sidebar can render "Bank transfer · ₹5,000".

## Cross-table invariants

These are the rules the system tries to keep true. When they break, you have
a bug:

1. **For every Account A**: `A.balance == sum(signed deltas of A's active transactions)`.
   - Maintained by `apply_balance_delta` (after_create) + `reverse_balance_delta` (before_destroy).
   - `accounts:recompute_balances` re-derives the right-hand side; drift is dev debris.

2. **For every Transaction T linked to Account A**: `T.date >= A.open_date`.
   - Enforced by `Transaction#date_after_account_open_date` validation.

3. **For every balance change on Account A**: an `Audited::Audit` row exists
   referencing A with a non-empty `comment`.
   - Maintained by every write going through `update!` inside
     `Audited.audit_class.as_user { acct.audit_comment = ...; ... }`.
   - `accounts:recompute_balances` uses `update_columns` (bypassing audit
     intentionally; followup is `audits:backfill`).

4. **For every Holding H on (UI, PA)**: stats reflect the FIFO walk over
   `user.investments.where(user_instrument: UI, platform_account: PA)`.
   - Maintained by `Holdings::RefreshJob` after each Investment write.

If you change a balance path or add a callback, walk through these four
invariants and confirm they still hold.

---

Last reviewed: 2026-05-11
