# Daily Snapshot Pipeline — 1M-User Scale Plan

## Context

The current daily price + P&L pipeline (just shipped) runs the entire workflow inside a single Sidekiq job that does `User.find_each` and, per user, iterates every `(user_instrument, platform_account)` pair to refresh the cache and write a snapshot. It works fine at small scale, but at 1M users × ~20 instruments avg the pipeline becomes:

- **20M position iterations** per day (= 1M users × 20 holdings).
- One serial Ruby thread, one DB connection, hours-to-days of wall-clock.
- A single user's failure retries the whole 20M-row job.
- ~50M new `holding_snapshots` rows/day → ~1.5B rows in 30 days, with no partitioning to keep vacuum and indexes healthy.

The reframing — **iterate per instrument, not per position** — collapses the top-level loop from 20M to ~5K (4,693 instruments today, growing slowly). Combined with bulk upserts inside each instrument's iteration, this is the big architectural win.

This plan is **forward-looking only**: ship in stages as user count grows. Land the cheap, non-breaking pieces first; defer the heavier lifts until pain shows.

---

## Decisions

| | |
|---|---|
| Timeline | Forward-looking; build incrementally as users grow |
| Retention | Keep daily detail forever (no weekly rollup) |
| Partitioning migration | Online via `pg_partman` |

---

## The redesign at a glance

```
05:00 IST tick
    │
    ▼
Daily::PriceAndPnlSnapshotJob (orchestrator, queue: daily_pnl_orchestrator)
    │ Phase 0: ensure next month's holding_snapshots partition exists
    │ Phase 1: Instruments::PriceFetchService.call (single HTTP fetch — global)
    │ Phase 2: SnapshotRun.create!(total_batches: N)
    │          slice instruments with active positions into ~100-instrument batches
    │          ActiveJob.perform_all_later([... batch_1 ... batch_N])
    ▼
[batch_1] [batch_2] … [batch_N]                 (queue: daily_pnl, concurrency 4-8)
    │ for each instrument I in this batch:
    │   load all (user_id × user_instrument × platform_account) positions touching I
    │   resolve current_price ONCE
    │   per position: PositionCalculator.call (FIFO walk) → stats
    │   collect rows, bulk upsert in chunks of 500:
    │     - holdings (Holding cache)
    │     - holding_snapshots (today's row)
    │     - investments (per-lot P&L via UPDATE … FROM VALUES)
    │ Redis DECR run counter; if last → enqueue finalize
    ▼ (only the last batch enqueues this)
Daily::SnapshotFinalizeJob (queue: daily_pnl)
    │ SystemTask("daily_pnl").mark_ok!
    │ schedule_next_run!  ← chain hand-off lives here, after run is fully done
    ▼
tomorrow 05:00 IST
```

### Why per-instrument, not per-user

| Unit of fan-out | Top-level iterations @ 1M users × 20 holdings | Wall-clock cost dominated by |
|---|---|---|
| Position (today) | 20,000,000 | per-row roundtrips |
| User batch | 2,000 batches × 500 users | still 20M per-row inside |
| **Instrument batch (this plan)** | **47 batches × 100 instruments** | **bulk upserts of cross-cutting positions** |

Per instrument the work amortises:

- 1 `PriceResolver` call (today: 1 per position).
- 1 SELECT to load ALL positions touching this instrument (today: 1 per position).
- 3 bulk UPSERTs in chunks of 500 (today: 3 single-row writes per position).

Total DB statements drop from **~100M** (5 statements × 20M positions) to **~50K** (4,693 instruments × ~10 statements + 47 control flows). That's the 2,000× reduction.

---

## Critical files

### To add

- `backend/app/jobs/daily/holding_snapshot_batch_job.rb` — per-instrument-batch worker
- `backend/app/jobs/daily/snapshot_finalize_job.rb` — last-batch hand-off, owns `schedule_next_run!`
- `backend/app/jobs/daily/ensure_partitions_job.rb` — Phase 0; creates next month's partition; idempotent
- `backend/app/services/reports/snapshot_batch_service.rb` — the per-instrument bulk-upsert engine; reuses `Holdings::PositionCalculator`, `Holdings::PriceResolver`
- `backend/app/models/snapshot_run.rb` + migration — durable run tracker
- `backend/db/migrate/<ts>_partition_holding_snapshots.rb` — converts table to declarative range partition (online via `pg_partman`)

### To modify

- `backend/app/jobs/daily/price_and_pnl_snapshot_job.rb` — switch from `Reports::HoldingSnapshotService.snapshot_all!` to instrument fan-out behind `ENV["DAILY_PNL_FANOUT"] == "true"`
- `backend/config/sidekiq.yml` — add `daily_pnl_orchestrator` (singular, weight 5) and `daily_pnl` (capped weight 4) queues
- `backend/Gemfile` — add `pg_partman` gem (only used by the Phase 0 job)
- `backend/app/services/reports/holding_snapshot_service.rb` — keep instance method (per-user path still useful for assistant tools / on-demand single-user refresh); deprecate `snapshot_all!` once fanout is the default

### Reuse as-is

- `Instruments::PriceFetchService` — already global, single HTTP fetch
- `Holdings::PositionCalculator` — pure FIFO function; no changes
- `Holdings::PriceResolver` — pure; resolved once per instrument inside batch service
- `SystemTask`, `Daily::PriceAndPnlSnapshotJob.{enqueue_for, schedule_next_run!, already_enqueued_for?}` — public surface unchanged; boot init keeps working

---

## Per-batch service shape (the critical piece)

`Reports::SnapshotBatchService` does the heavy lifting:

```ruby
class SnapshotBatchService
  def initialize(date:, instrument_ids:)
    @date = date
    @instrument_ids = instrument_ids
  end

  def call
    holdings_rows, snapshot_rows, lot_pnl_updates = [], [], []

    Instrument.where(id: @instrument_ids).find_each do |instrument|
      # ALL active positions touching this instrument across all users
      positions = Investment
        .joins(:user_instrument)
        .where(user_instruments: { instrument_id: instrument.id })
        .group_by { |inv| [inv.user_id, inv.user_instrument_id, inv.platform_account_id] }

      current_price = Holdings::PriceResolver.call(instrument, [], instrument.investment_type).first

      positions.each do |(uid, ui_id, pa_id), lots|
        stats = Holdings::PositionCalculator.call(lots, current_price: current_price, investment_type: instrument.investment_type)
        holdings_rows  << build_holding_row(uid, ui_id, pa_id, stats, instrument)
        snapshot_rows  << build_snapshot_row(uid, ui_id, pa_id, stats, instrument)
        lots.each { |lot| lot_pnl_updates << build_lot_pnl_update(lot, stats[:lot_pnl][lot.id]) }
      end
    end

    holdings_rows.each_slice(500)  { |c| Holding.upsert_all(c, unique_by: :uq_holding_user_instrument_account, update_only: STAT_COLS) }
    snapshot_rows.each_slice(500)  { |c| HoldingSnapshot.upsert_all(c, unique_by: :uq_holding_snapshot_per_day, update_only: STAT_COLS) }
    bulk_update_lot_pnl(lot_pnl_updates)  # UPDATE investments SET ... FROM (VALUES …)
  end
end
```

`bulk_update_lot_pnl` uses Postgres' `UPDATE … FROM (VALUES …)` to set `lot_realized_gain` / `lot_unrealized_gain` / `lot_pnl_at` for thousands of `investments` rows in one statement. Skips the `after_save_commit` callback (no model load).

### Concurrency throttling

`config/sidekiq.yml`:

```yaml
:concurrency: 8
:queues:
  - [imports, 3]
  - [daily_pnl_orchestrator, 5]   # singular, high priority
  - [daily_pnl, 4]                # batch jobs, capped weight
  - [default, 1]
```

Dedicated `daily_pnl` queue with weight 4 → at most 4 of 8 worker threads on any node pull batches; user-facing imports + default keep flowing.

### Completion tracking — open-source only

Two layers:

1. `snapshot_runs` table (durable): `(run_id pk, run_date, total_batches, completed_batches, failed_batches, started_at, finished_at, status)`.
2. Redis counter (fast path): `daily_pnl:run:<run_id>:remaining` set to N at fan-out, `DECR` per batch success. When zero → batch enqueues `SnapshotFinalizeJob`.

A safety-net `Daily::SnapshotReconcileJob`, scheduled `+2h` after fan-out, polls the counter and the Sidekiq dead set — handles the case where a batch dies in the dead set and never decrements. Reconciles `snapshot_runs` and either enqueues finalize or leaves the run in `failed` state for triage.

### Storage — partitioning + retention

- Convert `holding_snapshots` to **declarative range partition on `snapshot_date`**, monthly partitions, via `pg_partman` for online cutover.
- Existing unique index `(holding_id, snapshot_date)` stays valid (partition key included).
- Other indexes (`(user_id, snapshot_date)`, `(platform_account_id, snapshot_date)`) get inherited by every partition — important so chart queries prune to the relevant month range.
- **Retention: keep daily detail forever** (per decision). `pg_partman`'s retention is `infinite`. The cost is linear storage growth (~50M rows/day at 1M users, ~30GB/month) — accepted.
- A daily `EnsurePartitionsJob` is the orchestrator's Phase 0; it tells `pg_partman` to ensure the next 2 monthly partitions exist. Idempotent.

### Retry semantics

| Job | retry | rationale |
|---|---|---|
| `Daily::PriceAndPnlSnapshotJob` (orchestrator) | 5 | Phase 1 (NSE/AMFI fetch) is the only retryable work; fan-out itself is cheap. Today's `retry: 5` stays. |
| `Daily::HoldingSnapshotBatchJob` | 3 | Per-instrument-batch failures isolate to ~100 instruments × ~4K positions. |
| `Daily::SnapshotFinalizeJob` | 5 | Just stamps SystemTask + reschedules; idempotent. |
| `Daily::EnsurePartitionsJob` | 3 | Partition creation is idempotent. |

Each batch wraps its inner per-instrument loop in begin/rescue — one bad instrument increments a per-batch error counter without aborting the rest. Re-raise only if >50% of the batch failed (forces Sidekiq retry of just that batch). Kills the "one failure retries everyone" anti-pattern dead.

---

## Migration path (no flag day)

1. **Step 1 — partitioning only**. Land the `pg_partman` migration. Today's job keeps writing to the now-partitioned table; no behavior change.
2. **Step 2 — fan-out behind a flag**. Ship the new job classes + `SnapshotRun` model + `SnapshotBatchService` with `ENV["DAILY_PNL_FANOUT"] == "true"` gate in the orchestrator. Default off.
3. **Step 3 — flip in staging**. Generate ~10K dev users + 50K positions via FactoryBot, run with `DAILY_PNL_FANOUT=true`, verify wall-clock + Sidekiq Web shows ~50 batches → 1 finalize. Watch for partitioning misses.
4. **Step 4 — flip in prod**. Set the env var. Fall back by unsetting.
5. **Step 5 — cleanup PR (weeks later)**. Delete the legacy branch + `Reports::HoldingSnapshotService.snapshot_all!`. Keep `HoldingSnapshotService.new(user, date:).call` (assistant + admin still use it for per-user on-demand refresh).

Public API surface (`Daily::PriceAndPnlSnapshotJob.perform_later`, `enqueue_for`, `schedule_next_run!`) stays byte-identical at every step. `daily_pnl_catchup.rb` doesn't change.

---

## Test strategy (RSpec)

| Spec | What it asserts |
|---|---|
| `spec/jobs/daily/price_and_pnl_snapshot_job_spec.rb` | With fanout flag on: creates `SnapshotRun`, fans out the right number of batches, doesn't call `snapshot_all!`. With flag off: today's behavior. |
| `spec/jobs/daily/holding_snapshot_batch_job_spec.rb` | Given 3 instruments with positions across 5 users, writes 5 holdings + 5 snapshots; one bad instrument doesn't kill the whole batch; counter decrements. |
| `spec/jobs/daily/snapshot_finalize_job_spec.rb` | Stamps `SystemTask` only when `SnapshotRun.completed_batches == total_batches`; reschedules next 05:00 IST tick. |
| `spec/services/reports/snapshot_batch_service_spec.rb` | Per-instrument bulk upserts produce the same row values as today's per-position path; same edge cases (closed positions, sells > buys, MF folio_number). |
| `spec/jobs/daily/ensure_partitions_job_spec.rb` | Idempotent — running twice with the same date is a no-op; new partition exists when called near month-end. |

For the migration, add a backend integration test that runs the partitioning migration up + down in CI's test DB and confirms `holding_snapshots` accepts inserts at every step.

---

## Verification end-to-end

```ruby
# bin/rails runner db/seeds/scale_test.rb
# generates 10_000 users with avg 5 holdings → 50K positions across 4_693 instruments
ENV["DAILY_PNL_FANOUT"] = "true"
Daily::PriceAndPnlSnapshotJob.perform_now(Date.current.iso8601)

# Watch in Sidekiq Web (/sidekiq):
#   - 1 orchestrator job in daily_pnl_orchestrator queue (completes fast — Phase 1 + fan-out)
#   - ~47 batch jobs in daily_pnl queue (process in parallel, weight 4)
#   - 1 finalize job at the tail
#
# In Rails console after:
SnapshotRun.last
# => total_batches: 47, completed_batches: 47, failed_batches: 0, status: "completed"

HoldingSnapshot.on(Date.current).count
# => 50_000 (one per active position)

SystemTask.find_by(name: "daily_pnl").last_completed_date
# => Date.current
```

For real 1M scale validation in staging:

- FactoryBot + `Investment.insert_all` to generate 1M users × 1 holding each (50M rows is the partitioning stress test).
- Time the orchestrator + total wall-clock; expect ~30 min on a 4-worker fleet (8 threads × 4 = 32 batches in flight, ~50 batches total).
- Verify `pg_stat_user_indexes` to confirm chart queries prune to the right monthly partition.

---

## Out of scope for this plan

- **Sidekiq Pro / sidekiq-batch** — `SnapshotRun` + Redis counter does the same job for free.
- **Event-sourced redesign** — overkill; today's table-of-records model is fine.
- **Aggregated weekly rollup** — explicitly skipped per "keep daily detail forever" decision.
- **Read replica routing** for chart queries — separate plan; happens once analytics queries become a measured bottleneck.
- **Per-user-batch fan-out** — superseded by per-instrument fan-out; documented here so we don't relitigate.
