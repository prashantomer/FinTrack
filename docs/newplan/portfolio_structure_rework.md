# Portfolio Structure Rework

## Problems with the Current Design

### 1. FD/PPF duplicated across two models
`term_accounts` already handles FD and PPF correctly — with paired transactions, balance hooks, maturity calculations, and lifecycle management. But `investments.type` still includes `fixed_deposit` and `ppf`, creating two parallel paths to record the same thing. A user can create an FD as a term account (the right way) or as an investment row (wrong way, no balance hooks). This ambiguity causes incorrect net worth calculations and confusing UI.

### 2. InvestmentForm has fields that don't exist on the Investment model
`InvestmentForm.tsx` renders `ticker_symbol`, `exchange`, and `fund_house` as input fields. None of these columns exist on the `investments` table — they live on `instruments`. The form silently discards these values on submit. Users filling in a ticker symbol get no feedback that the data is lost.

### 3. Ambiguous row semantics: lot vs. aggregate position
`avg_buy_price` implies the row represents a running aggregate position (total units, blended average cost). But `purchase_date` and `transaction_public_id` imply it's a single purchase event (a lot). There is no mechanism to add more units to an existing position — each top-up becomes a separate row with its own `avg_buy_price`, making true average cost impossible to compute accurately.

### 4. `current_value` is a manual field with no history
There is no way to know what the portfolio was worth last week. Every update overwrites the previous value. XIRR, CAGR, and any time-dimension analytics are impossible.

### 5. No portfolio-level view
All investment rows are listed flat in a table. There is no grouping by instrument, no aggregate position view, and no allocation chart grounded in real positions. The dashboard's `investment_holdings` breakdown is by type only (total invested/value per type) — it does not show individual holdings.

---

## Proposed Architecture

### Phase 1 — Remove FD/PPF from the Investment model

**Backend:**
- Drop `fixed_deposit` and `ppf` from the `InvestmentType` PostgreSQL enum
- If any existing rows have these types, migrate them to `term_accounts` before dropping (write a data migration script, not just an Alembic DDL migration)
- Remaining valid investment types: `stock`, `mutual_fund`, `gold`, `crypto`, `nps`, `real_estate`

**Frontend:**
- Remove `fixed_deposit` and `ppf` options from the type selector in `InvestmentForm`
- Update `InvestmentType` in `src/types/index.ts`

**Why this first:** Eliminates the duplication ambiguity so every subsequent calculation has a clean, single source of truth for each asset class.

---

### Phase 2 — Investment row = Purchase Lot

Clarify the semantics: **each row in `investments` represents one purchase event (a lot)**, not an aggregate position. This is the right model for accurate cost-basis tracking and future XIRR calculations.

**Implications:**
- A user buying the same stock in three separate transactions creates three rows
- The "position" (aggregate view) is computed from all lots for the same instrument
- `avg_buy_price` on each row = price paid in that specific lot (not running average)
- Running average and total units for a position = computed at query time, not stored

**Backend schema changes:**
- Rename `avg_buy_price` → `buy_price` (per-lot cost, no averaging implied)
- Add `quantity` / `units` as **required** for types where units are meaningful (stock, MF, crypto)
- `amount_invested` = `buy_price × quantity` (can be auto-computed on create or user-provided)
- No new columns — just semantic clarification and minor rename

**Migration:** rename column via Alembic; update all references.

---

### Phase 3 — Enforce Instrument linkage for tradeable types

For `stock`, `mutual_fund`, `crypto`: `instrument_id` must be non-null. The instrument record is the canonical source for name, ticker symbol, ISIN, exchange, and fund house.

**Backend:**
- Add server-side validation in `investment_service.create_investment`: if `type in ('stock', 'mutual_fund', 'crypto')` and `instrument_id is None`, raise HTTP 422
- `InvestmentCreate` schema: add a validator for this rule

**Frontend:**
- In `InvestmentForm`, make `InstrumentCombobox` required (not optional) when type is stock/MF/crypto
- Remove `ticker_symbol`, `exchange`, `fund_house` input fields from the form entirely — these fields do not exist on the backend model; show them read-only from the linked instrument after selection instead
- `name` field for stock/MF/crypto: auto-populate from the selected instrument (still editable as an alias)

For `gold`, `nps`, `real_estate`: `instrument_id` remains optional.

---

### Phase 4 — Metadata column for type-specific fields

The current `investments` table has ~12 nullable columns covering type-specific details (FD fields already removed in Phase 1). These are hard to maintain and extend.

**Proposed change:** Add a `metadata JSONB` column. Move type-specific fields into it:

| Type | Fields moved to metadata |
|------|--------------------------|
| `gold` | `gold_form`, `weight_grams`, `purity` |
| `nps` | `nps_tier` (I/II), `nps_fund_manager`, `nps_scheme` |
| `real_estate` | `property_type`, `location`, `area_sqft` |

Core fields that stay as proper columns (needed for queries/aggregation):
- `quantity` / `units`, `buy_price`, `nav_at_purchase` (stock/MF/crypto)
- `folio_number` (mutual fund — used for deduplication)

**Migration:**
- Add `metadata JSONB` column (nullable, default `{}`)
- Write data migration to move existing type-specific values into `metadata`
- Drop `gold_form`, `weight_grams`, `purity` columns (and any remaining FD/PPF columns not already removed)

**Backend schemas:** `InvestmentCreate` / `InvestmentRead` expose `metadata: dict` as a pass-through. Validation of metadata keys happens in the service layer per type.

**Frontend:** Type-specific form sections write to the `metadata` dict rather than top-level fields.

---

### Phase 5 — Portfolio service and position view

A **position** = all lots for the same `instrument_id` (or same `name` for non-instrument types), aggregated.

**New `portfolio_service.py`:**
```
get_positions(db, user_id) → List[Position]
```
Where `Position` contains:
- `instrument_id`, `instrument_name`, `type`
- `total_lots`: count of individual purchase records
- `total_units` / `total_invested`
- `avg_buy_price`: weighted average across all lots = `sum(buy_price × quantity) / sum(quantity)`
- `current_value`: sum of `current_value` across lots (still manual for now — Phase 6 will improve this)
- `unrealized_gain`, `unrealized_gain_pct`

**New API endpoint:**
```
GET /api/v1/reports/portfolio
```
Returns positions grouped by type, plus overall totals. Replaces the current `investment-summary` endpoint (or coexists — `investment-summary` keeps its type-level breakdown, `portfolio` adds the per-instrument level).

**New schema:** `PortfolioReport` with `positions: List[PositionSummary]` and `by_type: List[InvestmentTypeBreakdown]`.

---

### Phase 6 — Portfolio page UI

Split the current single `InvestmentsPage` into two views:

**`InvestmentsPage` (lots)** — stays mostly as-is:
- Table of individual purchase records
- Create/edit/delete per lot
- Filter by type, instrument, date range

**`PortfolioPage` (positions)** — new page at `/portfolio`:
- Top: summary cards (total invested, current value, unrealized gain %)
- Middle: positions table grouped by type
  - Each row: instrument name, type badge, total units, avg buy price, current value, gain/loss (₹ and %)
  - Expandable row to see individual lots
- Bottom: asset allocation donut chart (by type, using current values)
- Route: add `/portfolio` to `App.tsx` protected routes

**Navigation:** Add "Portfolio" to the sidebar between Investments and Reports.

---

### Phase 7 — Current value update flow (UX improvement, no schema change)

Right now `current_value` is just an editable field. Make updating it intentional:

**Backend:** No schema change needed.

**Frontend:**
- In the positions table, add a "Update prices" action per position (or per lot)
- Small inline form: new current value → saves to all lots (or just the most recent lot, with a note)
- Show "last updated" timestamp (use `updated_at` already on the model)
- Future: this is where a price feed integration would hook in

---

## Summary of DB Schema Changes

| Change | Phase | Migration needed |
|--------|-------|-----------------|
| Drop `fixed_deposit`, `ppf` from `InvestmentType` enum | 1 | Yes — data migration + DDL |
| Rename `avg_buy_price` → `buy_price` | 2 | Yes |
| Make `quantity`/`units` required for market types | 2 | No (service-layer validation only) |
| Add `metadata JSONB` column | 4 | Yes |
| Drop `gold_form`, `weight_grams`, `purity` | 4 | Yes (after data migration to metadata) |

Total: 3 Alembic migrations (Phase 1 data migration can be combined with DDL; Phase 4 add + drop can be two separate migrations with a data migration between them).

---

## Delivery Order

Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7

Each phase is independently reviewable. Phases 1–4 are backend-heavy. Phases 5–7 add the new surface area (portfolio view). Phase 7 is optional polish.

**Phase 1 is the highest-priority unblock** — without it, any portfolio calculation double-counts FD/PPF assets.
