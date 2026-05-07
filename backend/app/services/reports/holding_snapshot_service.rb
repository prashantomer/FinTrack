module Reports
  # Captures a daily P&L snapshot for every active holding of a user. Reads
  # from `Holding` (the cached stat register) after refreshing it, so values
  # always reflect the latest live price written by Instruments::PriceFetchService.
  #
  # Idempotent: re-running for the same date upserts the same row.
  class HoldingSnapshotService
    def self.snapshot_all!(date: Date.current, logger: Rails.logger)
      total = 0
      User.find_each do |user|
        total += new(user, date: date, logger: logger).call
      end
      logger.info "[snapshots] Wrote #{total} holding snapshots for #{date}"
      total
    end

    attr_reader :user, :date

    def initialize(user, date: Date.current, logger: Rails.logger)
      @user   = user
      @date   = date
      @log    = logger
    end

    def call
      Holdings::RefreshService.refresh_all_for(user)

      rows = user.holdings.includes(user_instrument: :instrument).map do |h|
        {
          user_id:             user.id,
          holding_id:          h.id,
          platform_account_id: h.platform_account_id,
          user_instrument_id:  h.user_instrument_id,
          snapshot_date:       date,
          market_price:        h.user_instrument&.instrument&.last_price,
          total_units:         h.total_units,
          avg_buy_price:       h.avg_buy_price,
          total_invested:      h.total_invested,
          current_value:       h.current_value,
          unrealized_gain:     h.unrealized_gain,
          realized_gain:       h.realized_gain,
          is_closed:           h.is_closed
        }
      end

      return 0 if rows.empty?

      rows.each_slice(500).sum do |chunk|
        # Same-day re-runs replace the cached stats; created_at survives the
        # upsert (excluded from update_only), updated_at is auto-bumped by
        # Rails since record_timestamps defaults to true.
        HoldingSnapshot.upsert_all(
          chunk,
          unique_by:   :uq_holding_snapshot_per_day,
          update_only: %i[market_price total_units avg_buy_price total_invested
                          current_value unrealized_gain realized_gain is_closed]
        )
        chunk.size
      end
    end
  end
end
