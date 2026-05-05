# Portfolio Implementation Plan

> Supersedes `portfolio_structure_rework.md` for execution order.
> Written after aligning with UserInstrument refactor and InstrumentsPage rework.

---

## Context & Current State

| What | Current | Problem |
|---|---|---|
| `user_instruments` | Plain SQLAlchemy `Table` (junction) | Can't be FK-referenced by other tables |
| `follios.platform_id + instrument_id` | Direct links to platforms + instruments | Bypasses user's tracked instrument; no demat/platform account link |
| `investments.instrument_id` | Direct FK → instruments | Bypasses user's tracking context |
| `InvestmentType` | Includes `fixed_deposit`, `ppf` | Duplicates term_accounts; corrupts net worth |
| `avg_buy_price` | Implies aggregate position | Rows are actually lots (single buy events) |
| Portfolio view | None | Investments are a flat lot list only |

---

## Phase 0 — UserInstrument Entity Upgrade ✅ COMPLETE

**Goal:** Make `user_instruments` a proper ORM model with its own `id`, so
`follios` and `investments` can FK into it. The user's "track instrument" action
now creates a `UserInstrument` row — same UX, real entity.

> **Note:** Alembic `stamp` command didn't persist against psycopg3 — migration was applied
> manually via `psql` and `alembic_version` updated directly. Migration file
> `20260505191508` is at head. Frontend type-checks clean.

### DB Changes

**`user_instruments` table** (drop + recreate via migration)

| Column | Type | Notes |
|---|---|---|
| id | PK serial | **new** |
| user_id | FK → users CASCADE | |
| instrument_id | FK → instruments CASCADE | |
| added_at | timestamptz server_default now() | |
| | UNIQUE(user_id, instrument_id) | |

**`follios` table** (alter columns)

| Column | Before | After |
|---|---|---|
| `platform_id` FK → platforms | removed | — |
| `instrument_id` FK → instruments | removed | — |
| `user_instrument_id` | — | FK → user_instruments CASCADE |
| `platform_account_id` | — | FK → platform_accounts CASCADE |
| UNIQUE | (user_id, platform_id, instrument_id) | (user_instrument_id, platform_account_id) |

**`investments` table** (alter column)

| Column | Before | After |
|---|---|---|
| `instrument_id` FK → instruments | removed | — |
| `user_instrument_id` | — | FK → user_instruments SET NULL (nullable) |

### Backend Files

| File | Change |
|---|---|
| `models/instrument.py` | Replace `user_instruments` Table with `UserInstrument(Base)` ORM model; rewire `Instrument.trackers` relationship |
| `models/follio.py` | Replace `platform_id+instrument_id` FKs with `user_instrument_id+platform_account_id` |
| `models/investment.py` | Replace `instrument_id` with `user_instrument_id` |
| `models/__init__.py` | Import `UserInstrument` |
| `schemas/instrument.py` | Add `UserInstrumentRead` schema |
| `schemas/follio.py` | Update `FollioCreate` (accept `user_instrument_id+platform_account_id`), `FollioRead` (expose nested `user_instrument`) |
| `schemas/investment.py` | Replace `instrument_id` with `user_instrument_id` in Create/Read/Update |
| `services/instrument_service.py` | `track_instrument` → creates `UserInstrument` ORM row; `untrack_instrument` → deletes it; `list_tracked_instruments` → queries via `UserInstrument` model |
| `services/follio_service.py` | `_verify_instrument_tracked` → check `UserInstrument` by id; update create/update logic |
| `services/investment_service.py` | Remove `instrument_id` references; add `user_instrument_id` |
| `services/report_service.py` | Join through `UserInstrument` where `instrument_id` was used |
| `routers/instruments.py` | Add `GET /instruments/user-instruments` endpoint; Track/Untrack stay as-is |
| Alembic migration | Drop old `user_instruments` table; create new; alter `follios`; alter `investments` |

### Frontend Files

| File | Change |
|---|---|
| `types/index.ts` | Add `UserInstrument` type; update `Follio` (replace `platform_id+instrument_id` → `user_instrument_id+platform_account_id`); update `Investment` (replace `instrument_id` → `user_instrument_id`) |
| `api/instruments.ts` | Track/untrack calls unchanged; add `listUserInstruments()` |
| `hooks/useInstruments.ts` | Add `useUserInstruments()` hook |
| `pages/FolliosPage.tsx` | Form: pick UserInstrument (shows instrument name) then PlatformAccount |
| `components/investments/InvestmentForm.tsx` | Replace `InstrumentCombobox` (global catalogue) with UserInstrument picker; keep PlatformAccount select |

---

## Phase 1 — Remove FD/PPF from InvestmentType ✅ COMPLETE (extended: only stock + mutual_fund remain)

**Goal:** Term accounts are the single source of truth for FD and PPF.
Investments only cover market instruments + gold + NPS + real estate.

### DB Changes

New valid `InvestmentType` enum values: `stock`, `mutual_fund`, `gold`, `crypto`, `nps`, `real_estate`

Data migration required: any existing `investments` rows with `type IN ('fixed_deposit', 'ppf')` must be reviewed. Since this is a personal app with known data, write a script that prints them and errors if any exist before dropping enum values.

### Backend Files

| File | Change |
|---|---|
| `models/investment.py` | Remove `fixed_deposit`, `ppf` from `InvestmentType` enum |
| `schemas/investment.py` | Schemas auto-update from enum |
| Alembic migration | Data check → alter enum → remove values |

### Frontend Files

| File | Change |
|---|---|
| `types/index.ts` | Remove `'fixed_deposit' | 'ppf'` from `InvestmentType` |
| `lib/labels.ts` | Remove corresponding label entries |
| `components/investments/InvestmentForm.tsx` | Type dropdown auto-updates |

---

## Phase 2 — Purchase Lot Semantics + buy_price Rename ✅ COMPLETE

**Goal:** Each `investments` row = one buy event. Clarify naming.

### DB Changes

| Change | Detail |
|---|---|
| Rename `avg_buy_price` → `buy_price` | Per-lot cost paid, not a running average |
| `quantity` / `units` | Remain nullable; service validates required for stock/MF/crypto |

### Backend Files

| File | Change |
|---|---|
| `models/investment.py` | Rename column |
| `schemas/investment.py` | Rename field in all schemas |
| `services/investment_service.py` | Add validation: stock/MF/crypto must have `quantity` and `buy_price` |
| Alembic migration | `op.alter_column` rename |

### Frontend Files

| File | Change |
|---|---|
| `types/index.ts` | Rename `avg_buy_price` → `buy_price` |
| `components/investments/InvestmentForm.tsx` | Rename field; label "Buy Price" not "Avg Buy Price" |

---

## Phase 3 — Enforce Instrument Linkage for Tradeable Types ✅ COMPLETE

**Goal:** Stock, MF, crypto investments must link to a `UserInstrument`.
Name auto-fills from the instrument. Type-specific ticker/fund_house fields
shown read-only from the instrument (not editable on the investment row).

### Backend Files

| File | Change |
|---|---|
| `services/investment_service.py` | If `type in ('stock', 'mutual_fund', 'crypto')` and `user_instrument_id is None` → HTTP 422 |
| `schemas/investment.py` | Model validator for the rule |

### Frontend Files

| File | Change |
|---|---|
| `components/investments/InvestmentForm.tsx` | UserInstrument picker required for stock/MF/crypto; name auto-fills from selection (still editable as alias); read-only instrument details panel shows ticker, exchange, ISIN |

---

## Phase 4 — Metadata JSONB (Deferred)

Low priority. Move `gold_form / weight_grams / purity` into `metadata JSONB`.
NPS and real estate extensions go here too.

Not blocking portfolio view — defer until after Phase 6.

---

## Phase 5 — Portfolio Service ✅ COMPLETE

**Goal:** Aggregate lots into positions. New `GET /api/v1/reports/portfolio` endpoint.

### Position Definition

A **position** = all investment lots for the same `user_instrument_id` (or same `name` for non-instrument types like gold, NPS, real estate).

### `PortfolioPosition` schema

```python
class PortfolioPosition(BaseModel):
    user_instrument_id: int | None
    instrument_name: str
    instrument_ticker: str | None
    type: InvestmentType
    platform_accounts: list[str]        # nicknames of platforms holding this position
    total_lots: int
    total_units: float | None           # sum(quantity) for stock/MF/crypto
    total_invested: float               # sum(amount_invested)
    avg_buy_price: float | None         # weighted: sum(buy_price*qty)/sum(qty)
    current_value: float                # sum(current_value ?? amount_invested)
    unrealized_gain: float
    unrealized_gain_pct: float
    lots: list[InvestmentRead]          # individual rows, for expand-in-table
```

### `PortfolioReport` schema

```python
class PortfolioReport(BaseModel):
    total_invested: float
    current_value: float
    unrealized_gain: float
    unrealized_gain_pct: float
    by_type: list[InvestmentTypeBreakdown]   # allocation slice per type
    positions: list[PortfolioPosition]        # sorted: by type then by current_value desc
```

### Backend Files

| File | Change |
|---|---|
| `schemas/report.py` | Add `PortfolioPosition`, `PortfolioReport` |
| `services/portfolio_service.py` (new) | `get_portfolio(db, user_id) → PortfolioReport` |
| `routers/reports.py` | Add `GET /reports/portfolio` |

---

## Phase 6 — Portfolio Page UI ✅ COMPLETE

**Route:** `/portfolio` — add to `App.tsx` protected routes and sidebar nav (between Investments and Reports).

### Layout

```
┌─ Portfolio ──────────────────────────────── [Refresh prices] ┐
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐ │
│  │ Invested    │  │ Current     │  │ Gain / Loss          │ │
│  │ ₹12,34,567  │  │ ₹14,20,000  │  │ +₹1,85,433  +15.0%   │ │
│  └─────────────┘  └─────────────┘  └──────────────────────┘ │
│                                                              │
│  ┌───────────────────────────┐  ┌──────────────────────────┐ │
│  │ Allocation  (Donut chart) │  │ By Platform  (Bar chart) │ │
│  │  • Stocks  45%            │  │  Zerodha   ₹8L           │ │
│  │  • MF      35%            │  │  Groww     ₹4L           │ │
│  │  • Gold    20%            │  │  Direct    ₹2L           │ │
│  └───────────────────────────┘  └──────────────────────────┘ │
│                                                              │
│  Positions ─────────────────────────────────────────────── │
│                                                              │
│  STOCKS  (4)                                                 │
│  ┌────────────────┬──────┬────────┬───────────┬────────────┐ │
│  │ Instrument     │ Lots │ Units  │ Avg Price │ Gain       │ │
│  ├────────────────┼──────┼────────┼───────────┼────────────┤ │
│  │ ▶ RELIANCE     │  3   │  150   │ ₹2,400   │ +18.3%     │ │
│  │   ├ Lot 1  50u @ ₹2,200  2024-01-15  [Zerodha]        │ │
│  │   ├ Lot 2  60u @ ₹2,450  2024-03-20  [Zerodha]        │ │
│  │   └ Lot 3  40u @ ₹2,600  2024-07-01  [Zerodha]        │ │
│  │ ▶ INFY         │  1   │  100   │ ₹1,500   │  +6.7%     │ │
│  └────────────────┴──────┴────────┴───────────┴────────────┘ │
│                                                              │
│  MUTUAL FUNDS  (2)                                           │
│  ...                                                         │
└──────────────────────────────────────────────────────────────┘
```

### Components

| Component | File | Notes |
|---|---|---|
| `PortfolioPage` | `pages/PortfolioPage.tsx` | Main page; fetches `usePortfolio()` |
| `PortfolioSummaryCards` | inline | 3 cards: invested / current / gain |
| `AllocationChart` | inline | Recharts `PieChart` (donut) by type; uses existing color tokens |
| `PlatformBreakdownChart` | inline | Recharts `BarChart` horizontal; by platform account |
| `PositionsTable` | inline | Grouped by type; expandable rows |
| `LotRow` | inline | Expanded sub-row per lot |

### Frontend Files

| File | Change |
|---|---|
| `api/reports.ts` | Add `getPortfolio()` |
| `hooks/useReports.ts` | Add `usePortfolio()` |
| `types/index.ts` | Add `PortfolioPosition`, `PortfolioReport` |
| `pages/PortfolioPage.tsx` | New page |
| `App.tsx` | Add `/portfolio` route |
| `components/layout/Sidebar.tsx` | Add Portfolio nav item |

---

## Delivery Order

```
Phase 0  →  Phase 1  →  Phase 2  →  Phase 3  →  Phase 5  →  Phase 6  →  [Phase 4 later]
```

Each phase is independently reviewable. Backend changes in a phase come before frontend changes for the same phase.

### Migration sequence

| Phase | Migration name | Key operation |
|---|---|---|
| 0 | `upgrade_user_instruments_entity` | Drop junction table → create ORM table; alter follios; alter investments |
| 1 | `remove_fd_ppf_investment_types` | Alter enum (data check first) |
| 2 | `rename_avg_buy_price_to_buy_price` | Column rename |
| 4 (deferred) | `add_investment_metadata_jsonb` | Add column, data migration, drop type columns |

---

## What NOT Changing

- `InstrumentsPage` browse + track/untrack UX (already reworked with infinite scroll)
- `FolliosPage` CRUD shell (just updating form fields)
- Transaction immutability rules
- Term account FD/PPF logic
- Dashboard caching layer
