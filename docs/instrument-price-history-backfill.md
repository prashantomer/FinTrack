# Instrument Price History Backfill (1 Year)

## Context

`Instruments::PriceFetchService` only fetches **today's** prices — one NSE bhavcopy + one AMFI `NAVAll.txt` snapshot per run. The `instrument_price_history` table accumulates forward as the daily Sidekiq cron fires; there is no facility to fill in the past. The upcoming Instrument Profile page needs at least a year of daily prices to render the price-history chart and the cost-basis-vs-market-value series — without backfill, every profile would render an essentially empty chart for existing users until the daily job has run for ~252 trading days.

This plan adds a one-shot backfill that:
- Runs as `bin/rails instruments:backfill_prices [DAYS=365]`
- Fans out via Sidekiq so a long fetch loop doesn't block the rake invocation
- Targets **only tracked instruments** (anything in `user_instruments`) — skipping the ~6k+ catalogue rows the user doesn't care about
- Covers **stocks (NSE bhavcopy)** and **mutual funds (AMFI historical NAV)**
- Is idempotent — re-runs upsert into the existing `(instrument_id, price_date)` unique index, so partial failures can be retried freely

## Approach

### Service — `app/services/instruments/price_backfill_service.rb` (new)

Single class that exposes two pure entry points so the Sidekiq jobs stay thin:

- `.nse_for_date(date, stock_instrument_ids)` — fetches `https://archives.nseindia.com/products/content/sec_bhavdata_full_<DDMMYYYY>.csv`, filters to the supplied stock id set, upserts into `instrument_price_history` with `source: "nse_bhavcopy"`. Returns `{ inserted:, unmatched:, skipped_non_trading: }`. Treats HTTP 404 as a non-trading day (weekend/holiday) and returns `skipped_non_trading: true` instead of raising.
- `.amfi_for_range(from_date, to_date, mf_isins)` — fetches `https://portal.amfiindia.com/DownloadNAVHistoryReport_Po.aspx?frmdt=<DD-MMM-YYYY>&todt=<DD-MMM-YYYY>` (the date-range variant of NAVAll, semicolon-separated, includes a date column per row). Filters to the supplied ISIN set, upserts. Returns `{ inserted:, unmatched:, invalid: }`.

Both methods reuse the existing `upsert_all` pattern from `Instruments::PriceFetchService#upsert_history` — same `unique_by: :uq_instr_price_history_per_day`, same `update_only: %i[price source]`, batched at 1000 rows. Extract that helper into the new service (or move it to a shared module `Instruments::PriceHistoryUpsert`) so both daily and backfill paths share one definition.

HTTP fetch + retry logic comes from `Instruments::PriceFetchService#fetch_url` — extract or call into it. Don't duplicate.

### Jobs — `app/jobs/instruments/`

- `backfill_nse_prices_job.rb` — `perform(date_iso, stock_ids)`. Wraps `PriceBackfillService.nse_for_date`. Logs to `Rails.logger` with `[backfill nse <date>]` prefix. Sidekiq retry config: 5 attempts (NSE archive occasionally returns 503).
- `backfill_amfi_navs_job.rb` — `perform(from_iso, to_iso, mf_isins)`. Wraps `PriceBackfillService.amfi_for_range`. Same retry policy.

Both jobs land on the existing `:default` queue — Sidekiq default concurrency (10) throttles the NSE archive nicely. Don't create a new queue unless throughput becomes an issue.

### Rake task — `lib/tasks/instruments.rake` (extend)

Add a `backfill_prices` task to the existing `namespace :instruments do` block:

```ruby
desc "Backfill daily price history for tracked instruments (NSE stocks + AMFI MFs)"
task backfill_prices: :environment do
  days = Integer(ENV.fetch("DAYS", "365")).clamp(1, 1825)
  end_date   = Date.current
  start_date = end_date - days

  tracked_instrument_ids = UserInstrument.distinct.pluck(:instrument_id)
  stocks  = Instrument.where(id: tracked_instrument_ids, investment_type: "stock")
                      .where.not(ticker_symbol: nil)
  mfs     = Instrument.where(id: tracked_instrument_ids, investment_type: "mutual_fund")
                      .where.not(isin: nil)

  stock_ids = stocks.pluck(:id)
  mf_isins  = mfs.pluck(:isin)

  # NSE: one fetch per trading day. Skip weekends; let the job log the rest
  # (holidays are detected by HTTP 404 and treated as non-trading days).
  nse_jobs = 0
  (start_date..end_date).each do |d|
    next if d.saturday? || d.sunday?
    Instruments::BackfillNsePricesJob.perform_later(d.iso8601, stock_ids)
    nse_jobs += 1
  end

  # AMFI: chunk the window into 30-day spans so each request stays under the
  # portal's date-range cap (empirically ~90 days, but 30 is a safe headroom).
  amfi_jobs = 0
  cursor = start_date
  while cursor <= end_date
    chunk_end = [cursor + 29, end_date].min
    Instruments::BackfillAmfiNavsJob.perform_later(cursor.iso8601, chunk_end.iso8601, mf_isins)
    cursor = chunk_end + 1
    amfi_jobs += 1
  end

  puts "Enqueued: #{nse_jobs} NSE day-jobs, #{amfi_jobs} AMFI range-jobs"
  puts "Window: #{start_date} → #{end_date}"
  puts "Tracked: #{stock_ids.size} stocks, #{mf_isins.size} mutual funds"
  puts "Watch progress: tail logs/instrument_fetch.log or /sidekiq UI"
end
```

For 1 year on a typical user (~50 tracked instruments): roughly 252 NSE jobs + ~13 AMFI jobs = ~265 jobs. With Sidekiq default concurrency 10 and ~2-5s per NSE fetch, completion in 5-10 minutes wall clock.

### Specs

- `spec/services/instruments/price_backfill_service_spec.rb` — stub HTTP via WebMock. Cover: NSE happy path inserts rows, NSE 404 returns `skipped_non_trading`, AMFI happy path with multiple dates per scheme, AMFI invalid rows skipped, idempotency on re-run (no duplicate rows, same count), filter-to-tracked-ids excludes catalogue rows.
- `spec/jobs/instruments/backfill_nse_prices_job_spec.rb` and `…amfi_navs_job_spec.rb` — confirm the jobs delegate to the service and surface logger output.

No request-spec changes needed — this is all internal.

### Observability

- Service writes a one-line summary per call (matching the existing `[prices] NSE: updated=… history_rows=… unmatched=…` style in `PriceFetchService`).
- Sidekiq Web UI at `/sidekiq` already shows job throughput and failures.
- Failed jobs surface in Sidekiq's retry queue with the original args, so a re-enqueue is one click.

## Files

**Modified**
- `backend/app/services/instruments/price_fetch_service.rb` — extract `upsert_history` and `fetch_url` into shared helpers (likely a `Instruments::PriceHistoryUpsert` module + keep `fetch_url` reachable from the new service).
- `backend/lib/tasks/instruments.rake` — add `backfill_prices` task.

**Added**
- `backend/app/services/instruments/price_backfill_service.rb`
- `backend/app/jobs/instruments/backfill_nse_prices_job.rb`
- `backend/app/jobs/instruments/backfill_amfi_navs_job.rb`
- `backend/spec/services/instruments/price_backfill_service_spec.rb`
- `backend/spec/jobs/instruments/backfill_nse_prices_job_spec.rb`
- `backend/spec/jobs/instruments/backfill_amfi_navs_job_spec.rb`

## Reused (no new code)
- `InstrumentPriceHistory` model + the `uq_instr_price_history_per_day` unique index for idempotent upserts.
- `Instruments::PriceFetchService#fetch_url` for HTTP retry/redirect handling.
- The existing `:default` Sidekiq queue + `/sidekiq` Web UI.

## Verification

1. **Specs.** `cd backend && bundle exec rspec spec/services/instruments/price_backfill_service_spec.rb spec/jobs/instruments`.
2. **Dry run on a small window.** `cd backend && DAYS=5 bin/rails instruments:backfill_prices`. Watch `/sidekiq` — should see ~5 NSE jobs + 1 AMFI job. After completion, `bin/rails runner 'puts InstrumentPriceHistory.where(price_date: 5.days.ago..).group(:price_date).count'` shows rows per recent date.
3. **Full run.** `DAYS=365 bin/rails instruments:backfill_prices`. Tail `logs/instrument_fetch.log`; expect ~10 minute total wall clock for ~50 tracked instruments. Verify `InstrumentPriceHistory.distinct.count(:price_date)` is roughly 252 (NSE trading days) and that AMFI rows landed for each weekday in the window.
4. **Idempotency.** Re-run the same window. Row count should not change; check `InstrumentPriceHistory.maximum(:updated_at)` bumped (proving the upsert touched rows) but `count` is stable.
5. **Profile page sanity.** With backfill done, navigate to a held instrument's profile (once that page lands) — the 1y window pill should now render a populated price chart instead of a 1-2 point line.

## Out of scope (deferred)

- Backfilling the **untracked** catalogue. With ~6k+ instruments, MF historical fetches would be slow and most of them are unlinked to user data. Once the Instrument Profile page enables untracked profiles, we can revisit a wider backfill.
- A periodic **gap detection** job that re-runs the backfill for any date holes that appear (e.g., if the daily 5 AM job is down for a week). For now, manual re-run of the rake task fills gaps idempotently.
- Replacing `NSE_BHAVCOPY_URL_FORMAT` with the newer `BhavCopy_NSE_CM_0_0_0_<YYYYMMDD>_F_0000.csv.zip` format. The legacy URL still works at the time of writing; switch only if NSE retires it.
