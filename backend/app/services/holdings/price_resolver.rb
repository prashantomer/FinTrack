module Holdings
  # Resolves the per-unit current price for a position. Single source of truth
  # for the price-derivation chain shared by `Holdings::RefreshService` and
  # `Reports::PortfolioService`.
  #
  # Priority:
  #   1. `instrument.last_price` (live NSE bhavcopy / AMFI NAV) → "market"
  #   2. Per-lot manual `current_value` blended with avg buy price        → "manual"
  #   3. Weighted-average buy price (break-even fallback)                 → "cost"
  module PriceResolver
    QTY_EPSILON = 0.0001

    module_function

    # @return [Array(Float, String)] [current_price, source]
    def call(instrument, lots, investment_type)
      return [ instrument.last_price.to_f, "market" ] if instrument&.last_price.present?

      buys = lots.select(&:buy?)
      qty_of = ->(i) { (investment_type == "stock" ? i.quantity : i.units).to_f }

      buy_qty       = buys.sum { |i| qty_of.call(i) }
      total_buys    = buys.sum { |i| i.amount_invested.to_f }
      wavg_price    = buy_qty.positive? ? total_buys / buy_qty : 0.0

      manual_lots   = buys.select { |i| i.current_value.present? }
      manual_qty    = manual_lots.sum { |i| qty_of.call(i) }
      manual_total  = manual_lots.sum { |i| i.current_value.to_f }

      if manual_qty > QTY_EPSILON && buy_qty.positive?
        remaining = (buy_qty - manual_qty).clamp(0, Float::INFINITY)
        blended   = (manual_total + remaining * wavg_price) / buy_qty
        return [ blended, "manual" ]
      end

      [ wavg_price, "cost" ]
    end
  end
end
