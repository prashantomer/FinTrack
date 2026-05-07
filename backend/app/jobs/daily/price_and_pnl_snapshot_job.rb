module Daily
  # Orchestrates the daily 5 AM workflow:
  #   1. Fetch latest NSE bhavcopy + AMFI NAVs into instruments.last_price and
  #      instrument_price_history
  #   2. Snapshot every user's holdings into holding_snapshots
  #   3. Stamp SystemTask("daily_pnl") so a missed run can be detected on boot
  #
  # Idempotent. Safe to run multiple times in a single day; both writes are
  # upserts keyed on (instrument, date) and (holding, date) respectively.
  class PriceAndPnlSnapshotJob < ApplicationJob
    TASK_NAME = "daily_pnl".freeze
    queue_as :default

    def perform(date_iso = nil)
      date = date_iso ? Date.parse(date_iso) : Date.current
      task = SystemTask.named(TASK_NAME)

      Rails.logger.info "[daily_pnl] starting run for #{date}"
      began = Time.current

      Instruments::PriceFetchService.call
      written = Reports::HoldingSnapshotService.snapshot_all!(date: date)

      task.mark_ok!(at: Time.current, date: date)
      Rails.logger.info "[daily_pnl] complete in #{(Time.current - began).round(1)}s — #{written} snapshots"
    rescue => e
      Rails.logger.error "[daily_pnl] failed: #{e.class}: #{e.message}"
      SystemTask.named(TASK_NAME).mark_error!(e.message)
      raise
    end
  end
end
