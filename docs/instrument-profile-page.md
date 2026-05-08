# Instrument Profile Page

## Context

FinTrack already has rich per-instrument data — `Holdings::PositionCalculator` produces FIFO P&L, `Reports::PortfolioService` aggregates per-position lots, `instrument_price_history` stores daily prices — but none of it is reachable through a dedicated detail surface. From `/instruments` you currently see a flat list with no click-through; from `/holdings` you can only open a side-sheet of lots. We want a single deep page per instrument that surfaces:

- Market info (name, ticker/ISIN/exchange/fund_house, latest price)
- Price history chart with windows (7d/30d/90d/1y/all)
- The user's position summary (units held, avg buy, invested, current value, unrealized + realized gains, LT/ST split) when they hold it
- A cost-basis vs market-value time-series with buy/sell markers
- The lot list (with FIFO consumption metadata)
- Linked transactions (`transactions.instrument_id = X`)

For now, profiles only render for instruments the user holds (or has ever held). Untracked-instrument profiles are gated behind a project-level config + per-instrument flag so we can flip them on later without code changes.

## Approach (multi-thin endpoints + new SPA route)

### Backend — `backend/`

**1. New gating helper.** `app/services/instruments/profile_gate.rb`
- Pure module/class with `Instruments::ProfileGate.allowed?(user, instrument)`.
- Reads `Rails.application.config.x.fintrack.untracked_profile_mode` (env-driven, set in `config/application.rb` via `ENV.fetch("UNTRACKED_PROFILE_MODE", "off")` — values: `off | per_instrument | on`).
- If user has a `UserInstrument` for this instrument **OR** has any `Investment` linked to it → `true` (tracked profiles always work).
- Else, switch on the project mode: `off` → false, `on` → true, `per_instrument` → fall back to `instruments.profile_enabled` boolean.
- A new `before_action` on the four profile endpoints uses this and renders 404 when disallowed (don't leak existence with 403).

**2. Migration.** `db/migrate/<ts>_add_profile_enabled_to_instruments.rb`
- `add_column :instruments, :profile_enabled, :boolean, default: false, null: false`. No backfill needed (default off).

**3. New service.** `app/services/instruments/profile_service.rb`
- Single class wrapping the read-side computations so all four controller actions stay thin.
- `Instruments::ProfileService.new(user, instrument).position` → reuses the existing `Reports::PortfolioService#position_for` logic by extracting it into a pure method `Reports::PortfolioService.build_position(instrument, lots)` (or moving it to a peer module). Filters investments to one `user_instrument_id`.
- `.lots` → returns the same per-lot JSON shape `Reports::PortfolioService` already emits (`pnl`, `original_qty`, `consumed_qty`, `remaining_qty`, `consumed_from`).
- `.transactions(limit:, before:)` → `user.transactions.where(instrument_id: instrument.id)` ordered desc, paginated.
- `.price_history(days:)` → `InstrumentPriceHistory.for_instrument(id).where("price_date >= ?", days.days.ago).order(:price_date)`. Cap `days` at 365 × 5.

**4. Controller actions.** `app/controllers/api/v1/instruments_controller.rb` (extend; don't fork)
- `before_action :ensure_profile_allowed, only: [:position, :lots, :linked_transactions, :price_history]`
- `def position` → `render_success(data: Instruments::ProfileService.new(current_user, @instrument).position)`
- `def lots` → same shape as `Reports::PortfolioService` lot output for that one instrument.
- `def linked_transactions` → reuses `TransactionSerializer`. Accepts `?limit=` (default 50, max 200).
- `def price_history` → returns `[{ date, price }, ...]`. Accepts `?days=` (default 90, clamp 1..1825).
- All four are read-only; no writes. `show` (existing market-info endpoint) stays unchanged and is **not** gated — clients always need basic instrument info for navigation.

**5. Routes.** `config/routes.rb` — extend the existing `resources :instruments` block:
```ruby
resources :instruments, only: [:index, :show, :create, :update] do
  member do
    get :position
    get :lots
    get :linked_transactions, path: "transactions"
    get :price_history, path: "price-history"
    post :track     # existing
    delete :track   # existing → :untrack
  end
  collection do
    get :tracked    # existing
    get :types      # existing
  end
end
```
(Keep current routes' existing semantics; only add the four new member routes.)

**6. Specs.** `spec/services/instruments/profile_gate_spec.rb`, `spec/services/instruments/profile_service_spec.rb`, `spec/requests/api/v1/instruments/profile_spec.rb` (one file covering all four endpoints + gate states). Cover: tracked → 200; untracked + project_mode=off → 404; untracked + project_mode=on → 200; untracked + per_instrument + flag=true → 200; days clamp upper/lower; user isolation (other user's instrument → 404 not 403).

### Frontend — `frontend/`

**7. Types.** `src/types/index.ts`
- Reuse existing `Instrument`, `LotRead`, `PortfolioPosition`. Add a thin `InstrumentPositionSummary` type (subset of `PortfolioPosition` returned from `/position`).
- Add `InstrumentPricePoint = { date: string; price: number }`.

**8. API client.** `src/api/instruments.ts` — append four functions:
- `getInstrumentPosition(id)` → `GET /instruments/:id/position`
- `getInstrumentLots(id)` → `GET /instruments/:id/lots`
- `getInstrumentTransactions(id, { limit })` → `GET /instruments/:id/transactions`
- `getInstrumentPriceHistory(id, days)` → `GET /instruments/:id/price-history?days=N`

**9. Hooks.** `src/hooks/useInstruments.ts` — `useInstrumentProfile(id)` (umbrella that fans out four `useQuery`s, returns `{ instrument, position, lots, transactions, priceHistory, isLoading, isError }`); plus `useInstrumentPriceHistory(id, days)` separately so the window pills can refetch only that slice.

**10. New page.** `src/pages/InstrumentProfilePage.tsx`
- Layout matches the rest of the app: `flex flex-col h-full`, sticky `PageHeader` with name + ticker badge + back link, body uses `space-y-6` (per the flex-col-clipping gotcha) inside `flex-1 min-h-0 overflow-y-auto`.
- Sections (vertical):
  1. **Market header card** — name, ticker/exchange/ISIN/fund_house badges, last_price + last_price_at relative time.
  2. **Position summary** (only if `position` present): 4 stat cards — Units Held, Avg Buy, Invested, Current Value + Unrealized P&L + LT/ST split chips.
  3. **Price History chart** — Recharts `LineChart` with numeric ts X-axis + `xDomain` from `[now - days, now]` (lazy-init `now`). Window pills 7d/30d/90d/1y/all in card header. Buy/sell markers via a `Scatter` series layered on the same chart, colored green/red, anchored at `(purchase_date_ts, price_on_that_date)` — price falls back to lot price if no history row matches (small client-side join).
  4. **Cost Basis vs Market Value chart** — Recharts `LineChart` with two `Line`s sharing the X-axis. Series computed client-side from `lots + priceHistory` in a `useMemo`:
     - Build a per-day map from price history.
     - Walk lots ordered by `purchase_date`; for each day in the window, accumulate signed qty (buy=+, sell=−) and signed amount; emit `{ date, cost_basis, market_value: held_qty × price_on_day }`.
     - Forward-fill `price_on_day` from the latest history point on or before the date.
  5. **Lots table** — extract the existing per-lot row markup from `pages/HoldingsPage.tsx`'s `PositionLotsSheet` into a reusable `components/instruments/InstrumentLotsTable.tsx` (props: `lots: LotRead[]`). The Holdings page can keep using its sheet wrapper around the same component.
  6. **Linked Transactions table** — minimal Table reusing `Badge`, `formatCurrency`. "View all" link → `/transactions?instrument_id=:id` (out of scope for this PR; just leave the link; backend already supports the filter via existing query params if extended later).
- Empty/error states: if `position` returns 404 (untracked + gate disallows), show a placeholder card "This instrument profile is not enabled" rather than a hard error. If `position.is_closed`, show a "Fully exited" badge in the header and gray out the "Units Held" card.

**11. Routing.** `src/App.tsx` — add `<Route path="/instruments/:id" element={<InstrumentProfilePage />} />` inside the protected shell, after the `/instruments` route.

**12. Entry point.** `src/pages/InstrumentsPage.tsx` — wrap the instrument name cell in `<Link to={`/instruments/${ui.instrument.id}`}>`. No other entry points changed.

**13. Reusable extraction.** `src/components/instruments/InstrumentLotsTable.tsx` (new) — extract the lot row markup from `HoldingsPage.PositionLotsSheet`. Update `HoldingsPage` to use the extracted component. Avoids two copies of the same FIFO-consumption-aware row.

### Files

**Modified**
- `backend/config/routes.rb` — 4 new member routes on `instruments`.
- `backend/app/controllers/api/v1/instruments_controller.rb` — 4 new actions + `before_action :ensure_profile_allowed`.
- `backend/config/application.rb` — read `UNTRACKED_PROFILE_MODE` env into `config.x.fintrack.untracked_profile_mode`.
- `backend/app/services/reports/portfolio_service.rb` — extract `position_for` into a class method or peer module so `ProfileService` can reuse it.
- `frontend/src/api/instruments.ts`, `frontend/src/hooks/useInstruments.ts`, `frontend/src/types/index.ts`, `frontend/src/App.tsx`, `frontend/src/pages/InstrumentsPage.tsx`, `frontend/src/pages/HoldingsPage.tsx` (consume the extracted lots table).

**Added**
- `backend/db/migrate/<ts>_add_profile_enabled_to_instruments.rb`
- `backend/app/services/instruments/profile_gate.rb`
- `backend/app/services/instruments/profile_service.rb`
- `backend/spec/services/instruments/profile_gate_spec.rb`
- `backend/spec/services/instruments/profile_service_spec.rb`
- `backend/spec/requests/api/v1/instruments/profile_spec.rb`
- `frontend/src/pages/InstrumentProfilePage.tsx`
- `frontend/src/components/instruments/InstrumentLotsTable.tsx`

### Reused (no new code)
- `Holdings::PositionCalculator` (`backend/app/services/holdings/position_calculator.rb`) — sole source of FIFO/LT-ST math.
- `Holdings::PriceResolver` (`backend/app/services/holdings/price_resolver.rb`) — for `current_price` lookup.
- `InstrumentPriceHistory` model scopes (`for_instrument`, `on_or_before`, `latest_first`).
- `TransactionSerializer`, `InstrumentSerializer` — no change to shapes.
- `PageHeader`, `Card`, `Table`, `Badge` UI primitives.
- Recharts patterns from `pages/PortfolioPage.tsx` (numeric `ts` X-axis, lazy `now`, window pills, `fmtShortDate`).

### Constraints honored
- Profile page body uses `space-y-6`, not `flex flex-col gap-6` (Card+Recharts inside a column-flex stack clips when content overflows the viewport — Card has `overflow-hidden` and flex children shrink).
- `now` captured via `useState(() => Date.now())`; no `setState` in `useEffect`. The cost-basis series + buy/sell-markers join is built in `useMemo` (the repo's strict `react-hooks/purity` + `set-state-in-effect` lint rules block both anti-patterns).
- Do not import the lucide-react `Lock` icon here. Use a text chip ("Profile disabled") for untracked-blocked states.
- Page is read-only — no PUT, no DELETE actions. Lot rows are non-interactive; transactions sub-table just links out to `/transactions`.

## Verification

1. **Backend specs.** `cd backend && bundle exec rspec spec/services/instruments spec/requests/api/v1/instruments` — covers gate states, service correctness, controller payload shapes, days clamps, user isolation, untracked 404.
2. **Migration.** `bin/rails db:migrate && RAILS_ENV=test bin/rails db:migrate` runs cleanly; new column `profile_enabled` defaults to false.
3. **Manual: tracked instrument.** Start servers (`bin/rails server` + `npm run dev`), log in, click an instrument name on `/instruments`. Verify the four sections render, window pills 7d/30d/90d/1y/all visibly shift the price chart's X-axis (data may be sparse but axis range moves), buy/sell markers land on the price line near the lot dates, cost-basis vs market-value lines diverge after a buy, lots table shows FIFO consumption fields.
4. **Manual: gated instrument.** Pick an instrument the user does *not* hold; navigate directly to `/instruments/:id`. Expect a "profile disabled" placeholder. Set `UNTRACKED_PROFILE_MODE=on` in `backend/.env`, restart Rails, reload — full page should now render with empty position section. Set back to `off`, restart, set `instruments.profile_enabled=true` for that row, set `UNTRACKED_PROFILE_MODE=per_instrument`, reload — page renders. Set the flag back to false — placeholder again.
5. **Lint + typecheck.** `cd frontend && npx tsc --noEmit && npm run lint`; `cd backend && bundle exec rubocop`.
6. **End-to-end.** `bin/pre-push-checks` runs the full quality gate (rspec + rubocop + brakeman + bundler-audit + eslint + tsc + vite build) — must pass before commit.

## Out of scope (deferred)

- Project-level toggle UI (admin page that flips `UNTRACKED_PROFILE_MODE` at runtime). The env-var approach is enough for the foreseeable future; can swap to a `system_settings` table row later without changing the gate's interface.
- Per-instrument "enable profile" affordance in the UI. For now, flipping `instruments.profile_enabled` is a console-only operation.
- A `?instrument_id=` filter on the transactions list page (the profile page links to it but the filter itself is a separate small change).
- Replacing the Holdings PositionLotsSheet with full-page navigation (per the v1 scope decision; Holdings keeps its sheet, just shares the inner table component).
