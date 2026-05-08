module Assistants
  module Tools
    # Surfaces the daily P&L time series captured by
    # `Daily::PriceAndPnlSnapshotJob` to the assistant. Lets the LLM answer
    # questions like "how did my portfolio do this month?" or "which platform
    # grew the most this year?" without having to slice raw `holding_snapshots`.
    class QueryPerformance < Base
      def name; "query_performance"; end

      def description
        "Return the user's portfolio performance over a date window. " \
        "Includes total current value, unrealized gain, last-30-day realized " \
        "gain, a daily net-worth series (sum of current_value across all " \
        "holdings per day), and a per-platform stacked series (current_value " \
        "split by platform_account.nickname per day). Use this for any " \
        "question about portfolio movement over time, growth across " \
        "platforms, or P&L over a specific window. The number of returned " \
        "data points equals the number of days the daily snapshot job ran " \
        "in the requested window — empty arrays mean no snapshots yet."
      end

      def input_schema
        {
          type: "object",
          properties: {
            days: {
              type:        "integer",
              description: "Window length in days (1..365). Defaults to 90.",
              minimum:     1,
              maximum:     365
            }
          },
          additionalProperties: false
        }
      end

      def call(args)
        days = (args || {})["days"] || (args || {})[:days] || ::Reports::PerformanceService::DEFAULT_DAYS
        ::Reports::PerformanceService.new(user, days: days).call
      end
    end
  end
end
