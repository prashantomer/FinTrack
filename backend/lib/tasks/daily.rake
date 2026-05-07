namespace :daily do
  desc "Run the daily price fetch + P&L snapshot job synchronously"
  task pnl: :environment do
    Daily::PriceAndPnlSnapshotJob.perform_now
  end

  desc "Show last successful run timestamps for scheduled tasks"
  task status: :environment do
    SystemTask.find_each do |t|
      printf "%-24s last_ok=%-12s status=%-6s err=%s\n",
             t.name,
             t.last_completed_date&.iso8601 || "never",
             t.last_status || "—",
             t.last_error&.first(80)
    end
  end
end
