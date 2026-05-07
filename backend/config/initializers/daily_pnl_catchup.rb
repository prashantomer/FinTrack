# Boot kickstart for the self-rescheduling daily price + P&L job.
#
# `Daily::PriceAndPnlSnapshotJob` schedules its own next 05:00 IST run inside
# the job's `ensure` block. This initializer keeps the chain alive across
# restarts:
#   - If today's run hasn't completed (`SystemTask` is stale), enqueue an
#     immediate catch-up run. That run will reschedule tomorrow's tick.
#   - Otherwise, only ensure that a future-scheduled run exists. If Redis
#     was flushed or Sidekiq was newly started, this re-seeds the chain
#     without re-running the body.
#
# Skipped in:
#   - test          (suite would enqueue real jobs)
#   - rake / runner (CLI invocations don't need to enqueue background work)
Rails.application.config.after_initialize do
  next if Rails.env.test?
  next if defined?(Rails::Console)
  next if File.basename($PROGRAM_NAME) == "rake"

  in_server  = defined?(Puma)
  in_sidekiq = defined?(Sidekiq) && Sidekiq.server?
  next unless in_server || in_sidekiq

  begin
    task = SystemTask.named(Daily::PriceAndPnlSnapshotJob::TASK_NAME)
    today = Date.current

    if task.stale_for?(today)
      Rails.logger.info "[daily_pnl] boot catch-up — last=#{task.last_completed_date.inspect}, enqueuing for #{today}"
      Daily::PriceAndPnlSnapshotJob.enqueue_for(today)
    else
      # Today is already done. Just make sure tomorrow's tick is on the queue.
      Daily::PriceAndPnlSnapshotJob.schedule_next_run!
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError => e
    # Tables may not exist yet during the very first migration; silently skip.
    Rails.logger.info "[daily_pnl] boot catch-up skipped: #{e.class}"
  end
end
