module Reports
  # Surfaces the daily P&L time series captured by
  # `Daily::PriceAndPnlSnapshotJob`. Returns three pieces:
  #   - net_worth_series:    [{ date:, value: }] — sum of current_value per day
  #   - per_platform_series: [{ date:, "<platform>": value, ... }] — stacked by platform_account.nickname
  #   - totals:              { current_value:, unrealized_gain:, realized_30d: }
  #
  # Read-only; no DB writes. Two GROUP BY snapshot_date queries on
  # `holding_snapshots`, scoped to the calling user. Re-runs are
  # cheap — we don't cache here; the caller can if they want.
  class PerformanceService
    DEFAULT_DAYS = 90
    MAX_DAYS     = 365

    def initialize(user, days: DEFAULT_DAYS)
      @user = user
      @days = clamp_days(days)
    end

    def call
      since = Date.current - @days.days
      base  = HoldingSnapshot.for_user(@user).since(since)

      {
        net_worth_series:    net_worth_series(base),
        per_platform_series: per_platform_series(base),
        totals:              totals(base),
        days:                @days
      }
    end

    private

    def clamp_days(value)
      [ [ value.to_i, 1 ].max, MAX_DAYS ].min
    end

    def net_worth_series(scope)
      scope
        .group(:snapshot_date)
        .order(:snapshot_date)
        .sum(:current_value)
        .map { |date, value| { date: date.iso8601, value: value.to_f.round(2) } }
    end

    def per_platform_series(scope)
      raw = scope
        .joins(:platform_account)
        .group(:snapshot_date, "platform_accounts.nickname")
        .order(:snapshot_date)
        .sum(:current_value)

      # raw is { [date, nickname] => value }. Pivot to one row per date with
      # nickname columns so Recharts' stacked area can read each as a series.
      raw.group_by { |(date, _), _| date }
         .map do |date, rows|
           row = { date: date.iso8601 }
           rows.each { |(_, nickname), value| row[nickname] = value.to_f.round(2) }
           row
         end
    end

    def totals(scope)
      latest_date = scope.maximum(:snapshot_date)
      latest = if latest_date
        scope.where(snapshot_date: latest_date)
             .pick(Arel.sql("COALESCE(SUM(current_value), 0)"), Arel.sql("COALESCE(SUM(unrealized_gain), 0)"))
      end
      current_value, unrealized_gain = latest || [ 0, 0 ]

      realized_30d = HoldingSnapshot.for_user(@user)
                                    .since(30.days.ago.to_date)
                                    .sum(:realized_gain)
                                    .to_f.round(2)

      {
        current_value:   current_value.to_f.round(2),
        unrealized_gain: unrealized_gain.to_f.round(2),
        realized_30d:    realized_30d
      }
    end
  end
end
