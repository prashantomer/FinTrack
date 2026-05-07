# Catch-up runner for the daily price + P&L snapshot job.
#
# `Daily::PriceAndPnlSnapshotJob` is normally fired by sidekiq-cron at 05:00
# IST. If the app was down at 05:00 (deploy, outage, laptop closed, …), the
# scheduled tick is silently lost — sidekiq-cron does not catch up missed runs.
# This initializer compensates: at boot, if today's run hasn't completed, it
# enqueues the job once.
#
# Skipped in:
#   - test          (suite would enqueue real jobs)
#   - rake / runner (CLI invocations don't need to enqueue background work)
#   - asset:precompile / db:* (Rails boots for these without a long-lived process)
Rails.application.config.after_initialize do
  next if Rails.env.test?
  next if defined?(Rails::Console)
  next if File.basename($PROGRAM_NAME) == "rake"

  # Only the web (Puma) and Sidekiq processes should arm catch-up.
  in_server  = defined?(Puma)
  in_sidekiq = defined?(Sidekiq) && Sidekiq.server?
  next unless in_server || in_sidekiq

  begin
    task = SystemTask.named(Daily::PriceAndPnlSnapshotJob::TASK_NAME)
    today = Date.current
    if task.stale_for?(today)
      Rails.logger.info "[daily_pnl] boot catch-up — last_completed_date=#{task.last_completed_date.inspect}, enqueuing for #{today}"
      Daily::PriceAndPnlSnapshotJob.perform_later(today.iso8601)
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError => e
    # Tables may not exist yet during the very first migration; silently skip.
    Rails.logger.info "[daily_pnl] boot catch-up skipped: #{e.class}"
  end
end
