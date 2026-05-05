# CSV Seeds & Bank Feature Rework

## Context

Rework the Bank feature (and related Transaction model) per `docs/Rework.txt`. Delivered incrementally — one phase at a time, user reviews before next.

**Decisions made:**
- FD/PPF account fields: **STI** (single `accounts` table, nullable extra columns)
- Tags on transactions: **PostgreSQL `text[]` array**
- Credit reference: user-provided bank ref (UTR/IMPS) stored in new `bank_ref` String column

---

## Migration Rules (apply to all phases)

- **No rollback**: every Alembic migration has only an `upgrade` path. The `downgrade` function raises `NotImplementedError` or is left as a no-op comment.
- **New migration for every change**: no manual `ALTER TABLE` in a shell. All schema changes go through `alembic revision --autogenerate` (reviewed and edited as needed).
- **Seeds can run from migrations**: a migration's `upgrade` function may call the seed loader directly (e.g. `load_csv_seed("banks")`) after schema changes. This ensures reference data is present as soon as the migration runs.

---

## Phase 1 — CSV Seed Infrastructure

**Goal:** All seed data lives in CSV files. CLI `seed` command and Alembic migrations both load from CSV with truncate-and-reload.

### Files to create
- `backend/seeds/banks.csv` — columns: `name,code,is_system`
- `backend/app/seeds.py` *(new shared helper)* — `load_csv_seed(table_name, db)`: reads `backend/seeds/<table>.csv`, truncates the table, inserts all rows where `is_active != false`

### Files to modify
- `backend/app/cli/banks.py` — replace hardcoded `SEED_BANKS` list; call `load_csv_seed("banks", db)` instead
- Alembic migrations that introduce reference tables will call `load_csv_seed(...)` at the end of `upgrade()`

---

## Phase 2 — Bank Model: Tighten `short_name` length

**Goal:** Keep `short_name` as-is; enforce max 6 chars via column constraint.

### Migration (Alembic, no downgrade)
- `op.alter_column("banks", "short_name", type_=sa.String(6))` — shrinks column from `String(20)` to `String(6)`

### Files to modify
| File | Change |
|---|---|
| `backend/app/models/bank.py` | `String(20)` → `String(6)` on `short_name` |
| `backend/seeds/banks.csv` | Ensure all `short_name` values are ≤ 6 chars |

---

## Phase 3 — FD & PPF Accounts (new `term_accounts` table with STI)

**Goal:** FD and PPF are stored in a dedicated `term_accounts` table (not on `accounts`). Within `term_accounts`, STI distinguishes FD vs PPF via a `type` column. The `accounts` table stays clean — no new columns, no enum changes.

### Table structure

**`accounts`** — add closure columns (migration required)
| Column | Type | Notes |
|---|---|---|
| `closed_date` | Date, nullable | filled on account closure |
| `closed_amount` | Numeric(14,2), nullable | final balance on closure |

`is_active` set to `False` when closed. All other existing columns unchanged.

**`term_accounts`** — new table
| Column | Type | Notes |
|---|---|---|
| `id` | PK | |
| `user_id` | FK → users.id (CASCADE) | |
| `bank_id` | FK → banks.id (RESTRICT) | must match parent account's bank |
| `parent_account_id` | FK → accounts.id (RESTRICT) | required; must be savings/current, same user, same bank |
| `type` | Enum `term_account_type`: `fd`, `ppf` | STI discriminator |
| `account_number` | String(100) | Type Initial as Prefix, i.e. "FD#xxxx"|
| `amount` | Numeric(14,2) | principal (FD) or initial contribution (PPF) |
| `open_date` | Date | |
| `tenure_days` | Integer, nullable | FD only |
| `interest_rate` | Numeric(5,2) | |
| `maturity_date` | Date | auto-calculated on create |
| `maturity_amount` | Numeric(14,2) | auto-calculated on create |
| `balance` | Numeric(14,2), default 0 | running balance driven by transactions |
| `closed_date` | Date, nullable | filled on account closure |
| `closed_amount` | Numeric(14,2), nullable | actual amount received on closure |
| `is_active` | Boolean, default True | |
| `created_at` | DateTime | |

### Computed field formulas (service layer, stored on create)
- FD `maturity_date` = `open_date + tenure_days`
- FD `maturity_amount` = `amount × (1 + rate/100 × tenure_days/365)`
- PPF `maturity_date` = `open_date + 15 years`
- PPF `maturity_amount` = **user-provided** (PPF compounding varies yearly; not estimated)

### Field notes
- `closed_date` and `closed_amount` — filled only when the account matures/closes; `is_active` set to `False` at the same time

### Validation rules (service layer)
- `parent_account_id` must point to a `savings` or `current` account owned by same user at same bank
- PPF `tenure_days` must be null (maturity is always 15 years)

### Transaction linkage (polymorphic)
Replace the current `account_id` FK with a polymorphic pair — no DB-level FK constraint (resolved in service layer):

| Column | Type | Notes |
|---|---|---|
| `linked_account_type` | Enum `linked_account_type`: `account`, `term_account` | discriminator |
| `linked_account_id` | Integer | ID in the referenced table |

- Savings/Current transactions: `linked_account_type = account`, `linked_account_id = accounts.id`
- FD/PPF transactions: `linked_account_type = term_account`, `linked_account_id = term_accounts.id`
- Service layer resolves the correct model based on `linked_account_type` before applying balance delta
- Migration: drop `account_id` FK column, add `linked_account_type` + `linked_account_id`; migrate existing rows to `linked_account_type = account`

### Migration (Alembic, no downgrade)
- Create `term_account_type` PG enum (`fd`, `ppf`)
- Create `term_accounts` table
- Create `linked_account_type` PG enum (`account`, `term_account`)
- On `transactions`: drop FK constraint + `account_id` column; add `linked_account_type` (enum, nullable) + `linked_account_id` (Integer, nullable)
- Data migration: set `linked_account_type = 'account'`, `linked_account_id = old account_id` for all existing rows where `account_id IS NOT NULL`

### Files to create/modify
| File | Change |
|---|---|
| `backend/app/models/term_account.py` *(new)* | `TermAccountType` enum + `TermAccount` model |
| `backend/app/models/__init__.py` | Import `TermAccount` |
| `backend/app/schemas/term_account.py` *(new)* | `TermAccountCreate`, `TermAccountRead` |
| `backend/app/services/term_account_service.py` *(new)* | `create_term_account` (validates + computes maturity + triggers paired transactions) |
| `backend/app/routers/term_accounts.py` *(new)* | GET/POST `/term-accounts`, GET `/term-accounts/{id}` |
| `backend/app/main.py` | Register new router |
| `backend/app/models/transaction.py` | Add `term_account_id` FK + relationship |
| `frontend/src/types/index.ts` | Add `TermAccount` type; extend `Transaction` with `term_account_id` |
| `frontend/src/api/term_accounts.ts` *(new)* | `listTermAccounts`, `createTermAccount` |
| `frontend/src/hooks/useTermAccounts.ts` *(new)* | React Query hooks |
| `frontend/src/pages/AccountsPage.tsx` | Add FD/PPF section alongside savings table |

---

## Phase 4 — Transaction Model Rework

**Goal:** Rename `inbound/outbound` → `credit/debit`; replace `category` with `tags text[]`; add `bank_ref`; enforce UI immutability.

### Schema changes
| Change | Detail |
|---|---|
| `type` enum | `inbound → credit`, `outbound → debit` — new PG enum, migrate data, drop old |
| Remove `category` column | Drop `TransactionCategory` enum and column |
| Remove `notes` column | Merged into `description` |
| Add `tags` column | `ARRAY(Text)`, nullable, default `'{}'` |
| Add `bank_ref` column | `String(100)`, nullable — user-entered UTR/IMPS for credit transactions |
| `public_id` | Keep as UUID, auto-generated for all transactions |

### Immutability rules (enforced at API layer)
- Remove `PUT /transactions/{id}` endpoint
- Remove `DELETE /transactions/{id}` endpoint
- New CLI commands in `backend/app/cli/transactions.py`:
  - `correct` — update amount/type and recalculate balance
  - `deactivate` — set `is_active=False` and reverse balance delta

### Files to modify
| File | Change |
|---|---|
| `backend/app/models/transaction.py` | New enum, new columns, remove old columns |
| `backend/app/schemas/transaction.py` | Sync all schemas |
| `backend/app/services/transaction_service.py` | Update create logic; balance hook |
| `backend/app/routers/transactions.py` | Remove PUT/DELETE endpoints |
| `backend/app/cli/transactions.py` *(new)* | `correct`, `deactivate` commands |
| `frontend/src/types/index.ts` | Update `Transaction` type |
| `frontend/src/pages/TransactionsPage.tsx` | Remove edit/delete buttons; add tags input; add `bank_ref` field (credit only) |

---

## Phase 5 — Balance Hooks

**Goal:** Account balance auto-updates on every transaction event.

### Rules
| Event | Effect on balance |
|---|---|
| Credit transaction created | `account.balance += amount` |
| Debit transaction created | `account.balance -= amount` |
| Transaction deactivated (CLI) | Reverse the delta |
| Transaction corrected (CLI) | Reverse old delta, apply new delta |

### FD creation hook (triggered in `create_term_account` for `fd` type)
1. Validate parent savings account has balance ≥ FD amount
2. Create savings **debit** transaction (`account_id = parent_account_id`, amount = FD amount)
3. Create FD **credit** transaction (`term_account_id = new FD id`, same amount) — FD `balance` NOT incremented (FD balance tracks only credited/matured amounts per rework rules)
4. Deduct from parent savings account balance only

### PPF investment hook (triggered when creating a transaction for a PPF `term_account`)
1. Create savings **debit** transaction (`account_id = parent_account_id`)
2. Create PPF **credit** transaction (`term_account_id = ppf id`)
3. Deduct from savings balance; add to PPF balance

### Files to modify
| File | Change |
|---|---|
| `backend/app/services/term_account_service.py` | FD `create_term_account` triggers paired transactions |
| `backend/app/services/transaction_service.py` | `create_transaction` updates correct balance (`account.balance` or `term_account.balance`); add `_apply_balance_delta` helper |

---

## Phase 6 — UI Updates

| Page | Changes |
|---|---|
| `AccountsPage.tsx` | Separate savings vs FD vs PPF display; FD/PPF rows show maturity date + interest rate; remove manual balance field (balance is transaction-driven) |
| `TransactionsPage.tsx` | Remove Edit/Delete buttons; add tags input (comma-separated); add `bank_ref` field visible only when type = credit |
| `frontend/src/types/index.ts` | Full sync with new backend schemas |

---

## Verification

```bash
# Phase 1
cd backend && uv run python -m app.cli banks seed

# Phase 2
uv run alembic upgrade head
uv run pytest tests/test_banks.py -v

# Phase 3–5
uv run alembic upgrade head
uv run python -m app.cli seed --reset
uv run pytest tests/ -v

# Phase 6 — manual browser check
cd frontend && npm run dev
# - Create a savings account
# - Create an FD linked to it → verify savings balance decrements automatically
# - Add a credit transaction → verify balance increments; no edit/delete buttons shown
```

---

## Delivery Order

**Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6**

Each phase delivered and reviewed before the next begins.
