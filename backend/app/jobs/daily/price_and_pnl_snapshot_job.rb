module Daily
  # Self-rescheduling daily price + P&L workflow:
  #   1. Fetch latest NSE bhavcopy + AMFI NAVs into instruments.last_price and
  #      instrument_price_history
  #   2. Snapshot every user's holdings into holding_snapshots
  #   3. Stamp SystemTask("daily_pnl")
  #   4. Schedule the next run for tomorrow 05:00 IST (in `ensure`, so the
  #      chain survives a failure body — the schedule never dies)
  #
  # Idempotent at the data layer: both writes are upserts keyed on
  # (instrument, date) and (holding, date) respectively. Same-day re-runs
  # always re-fetch prices and refresh stats — they don't create duplicate
  # rows but they do bring values up to date if anything moved during the day.
  #
  # Retry policy: Sidekiq retries on failure up to 5 times with its default
  # exponential-with-jitter backoff (≈15s, ≈30s, ≈90s, ≈4m, ≈10m). Any
  # failure beyond that lands in the dead set for manual inspection.
  class PriceAndPnlSnapshotJob < ApplicationJob
    TASK_NAME = "daily_pnl".freeze
    RUN_HOUR  = 5  # 05:00 in Asia/Kolkata (Application.time_zone)

    queue_as :default
    sidekiq_options retry: 5

    # ── instance flow ──────────────────────────────────────────────────────

    def perform(date_iso = nil)
      date = date_iso ? Date.parse(date_iso) : Date.current
      task = SystemTask.named(TASK_NAME)

      Rails.logger.info "[daily_pnl] starting run for #{date}"
      began = Time.current

      # Both writes are upserts — re-running for the same date refreshes
      # values without creating duplicate rows.
      Instruments::PriceFetchService.call
      written = Reports::HoldingSnapshotService.snapshot_all!(date: date)

      task.mark_ok!(at: Time.current, date: date)
      Rails.logger.info "[daily_pnl] complete in #{(Time.current - began).round(1)}s — #{written} snapshots"
    rescue => e
      Rails.logger.error "[daily_pnl] failed: #{e.class}: #{e.message}"
      SystemTask.named(TASK_NAME).mark_error!(e.message) rescue nil
      raise
    ensure
      self.class.schedule_next_run!
    end

    # ── public class API ────────────────────────────────────────────────────

    # Enqueue an immediate run for a specific date. No-op if a job for the
    # same date is already enqueued, scheduled, or in retry. Used by the
    # boot catch-up initializer and `bin/rails daily:pnl`.
    def self.enqueue_for(date)
      iso = date.iso8601
      if already_enqueued_for?(iso)
        Rails.logger.info "[daily_pnl] job for #{iso} already enqueued/scheduled, skipping"
        return false
      end
      perform_later(iso)
      true
    end

    # Schedule the chain's next 05:00 IST run. Idempotent — bails out if a
    # job for tomorrow's date is already on the wire.
    def self.schedule_next_run!
      next_at = next_run_time
      iso = next_at.to_date.iso8601
      if already_enqueued_for?(iso)
        Rails.logger.debug "[daily_pnl] next run for #{iso} already scheduled, skipping"
        return false
      end
      Rails.logger.info "[daily_pnl] scheduling next run at #{next_at.iso8601}"
      set(wait_until: next_at).perform_later(iso)
      true
    rescue => e
      Rails.logger.error "[daily_pnl] failed to schedule next run: #{e.class}: #{e.message}"
      false
    end

    # 05:00 in the application time zone. If we're past it today, push to tomorrow.
    def self.next_run_time
      now = Time.current
      today_at_run_hour = now.beginning_of_day.change(hour: RUN_HOUR)
      now < today_at_run_hour ? today_at_run_hour : today_at_run_hour + 1.day
    end

    # ── deduplication ──────────────────────────────────────────────────────

    # True if a job for this date is already pending in any of: the default
    # queue (ready to run), the scheduled set (future-dated), or the retry
    # set (failed but pending re-attempt). Catches every place a duplicate
    # could be hiding.
    def self.already_enqueued_for?(date_iso)
      require "sidekiq/api"

      [ Sidekiq::Queue.new("default") ].any? do |queue|
        queue.any? { |job| matches_class_and_date?(job, date_iso) }
      end ||
        Sidekiq::ScheduledSet.new.any? { |entry| matches_class_and_date?(entry, date_iso) } ||
        Sidekiq::RetrySet.new.any?     { |entry| matches_class_and_date?(entry, date_iso) }
    rescue Redis::BaseError, RedisClient::Error
      # If Redis is unreachable we'd rather risk a duplicate than skip a
      # snapshot. The body itself is idempotent (same-day skip + upserts).
      false
    end

    # Sidekiq job entries wrap an ActiveJob payload — the date arg lives at
    # `job.args.first["arguments"][0]`. Match defensively across older
    # payload shapes too.
    def self.matches_class_and_date?(entry, date_iso)
      return false unless entry.respond_to?(:klass)
      return false unless [ name, "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper" ].include?(entry.klass)

      args = entry.args
      payload = args.is_a?(Array) && args.first.is_a?(Hash) ? args.first : nil
      return false unless payload

      job_class = payload["job_class"] || payload[:job_class]
      return false unless job_class == name

      job_args = payload["arguments"] || payload[:arguments] || []
      job_args.first == date_iso
    end
  end
end
