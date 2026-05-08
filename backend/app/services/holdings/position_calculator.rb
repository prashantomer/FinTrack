module Holdings
  # Pure-function position math. Single source of truth for cost-basis,
  # realized, and unrealized numbers across the app — invoked by
  # `Holdings::RefreshService` (writes the cached `Holding` row) and
  # `Reports::PortfolioService` (computes on-the-fly snapshot).
  #
  # Canonical method is FIFO (matches Indian brokers / ITR conventions).
  # A weighted-average (WAVG) comparison block is included alongside, used by
  # `Assistants::Tools::ExplainPortfolioPnl` for reconciliation answers.
  #
  # Pure: no DB writes, no callbacks. `lots` is an Array<Investment>; the
  # caller is responsible for narrowing the scope (single user_instrument,
  # single platform_account, or whatever).
  module PositionCalculator
    QTY_EPSILON = 0.0001
    # Long-term holding threshold in days. India treats equity & equity-oriented
    # MFs > 12 months as long-term capital gains; we apply the same threshold to
    # all instrument types here. Refine if/when debt MFs land (24/36-month rule).
    LT_DAYS = 365

    module_function

    # @param lots             [Array<Investment>] all buy + sell lots in the position
    # @param current_price    [Numeric] resolved per-unit market price (use {PriceResolver})
    # @param investment_type  [String]  "stock" or "mutual_fund"
    # @return [Hash] FIFO canonical fields + a `wavg:` comparison sub-hash + per-lot
    #               P&L map keyed by Investment#id under :lot_pnl, plus
    #               `long_term_units` / `short_term_units` for the held portion.
    def call(lots, current_price:, investment_type:)
      buys_sorted  = lots.select(&:buy?).sort_by  { |l| [ l.purchase_date, l.id ] }
      sells_sorted = lots.select(&:sell?).sort_by { |l| [ l.purchase_date, l.id ] }

      qty_of   = ->(i) { (investment_type == "stock" ? i.quantity : i.units).to_f }
      buy_qty  = buys_sorted.sum  { |i| qty_of.call(i) }
      sell_qty = sells_sorted.sum { |i| qty_of.call(i) }
      net_qty  = buy_qty - sell_qty

      # FIFO walk: consume earliest buy lots against sells in date order.
      # `buy_queue` carries the original Investment id + purchase_date so we can
      # bucket the held remainder by age and emit per-lot P&L afterwards.
      buy_queue          = buys_sorted.map { |i|
        { id: i.id, qty: qty_of.call(i), price: i.price.to_f, purchase_date: i.purchase_date }
      }
      cost_basis_of_sold = 0.0
      lot_pnl            = {}

      # Per-lot bookkeeping for the buy/sell register the UI renders. Same
      # FIFO walk; we just record what each sell consumed and how much each
      # buy gave away.
      original_qty_by_id  = buys_sorted.to_h { |i| [ i.id, qty_of.call(i) ] }
      consumed_qty_by_id  = Hash.new(0.0)
      sell_match_by_id    = Hash.new { |h, k| h[k] = [] }

      sells_sorted.each do |sell|
        remaining          = qty_of.call(sell)
        sale_consumed_cost = 0.0
        while remaining > QTY_EPSILON && buy_queue.any?
          head     = buy_queue.first
          consumed = [ remaining, head[:qty] ].min
          cost_basis_of_sold += consumed * head[:price]
          sale_consumed_cost += consumed * head[:price]

          consumed_qty_by_id[head[:id]] += consumed
          sell_match_by_id[sell.id] << {
            buy_id:   head[:id],
            buy_date: head[:purchase_date],
            qty:      consumed,
            price:    head[:price]
          }

          head[:qty] -= consumed
          remaining  -= consumed
          buy_queue.shift if head[:qty] <= QTY_EPSILON
        end
        # FIFO realized for THIS sell = its proceeds − cost basis it consumed.
        proceeds = sell.amount_invested.to_f
        gain     = proceeds - sale_consumed_cost
        pct      = sale_consumed_cost.positive? ? (gain / sale_consumed_cost) * 100 : nil
        lot_pnl[sell.id] = { value: gain, pct: pct, label: "Realized (FIFO)" }
      end

      # Emit per-lot register: original/consumed/remaining for each buy lot,
      # FIFO match trail for each sell lot. Consumers (UI, exports, assistant)
      # can slice this directly without re-running FIFO.
      lot_breakdown = {}
      buys_sorted.each do |b|
        orig = original_qty_by_id[b.id].to_f
        cons = consumed_qty_by_id[b.id].to_f
        rem  = (orig - cons)
        rem  = 0.0 if rem.abs < QTY_EPSILON
        lot_breakdown[b.id] = {
          original_qty:  orig,
          consumed_qty:  cons,
          remaining_qty: rem
        }
      end
      sells_sorted.each do |s|
        lot_breakdown[s.id] = { consumed_from: sell_match_by_id[s.id] }
      end

      fifo_held_qty   = buy_queue.sum { |b| b[:qty] }
      fifo_cost_basis = buy_queue.sum { |b| b[:qty] * b[:price] }

      # Per-lot unrealized for the still-held remainder of each buy lot.
      buy_queue.each do |b|
        next if b[:qty] <= QTY_EPSILON
        gain = b[:qty] * (current_price.to_f - b[:price])
        cost = b[:qty] * b[:price]
        pct  = cost.positive? ? (gain / cost) * 100 : nil
        lot_pnl[b[:id]] = { value: gain, pct: pct, label: "Unrealized (held #{b[:qty].round(4)} units)" }
      end

      # Long-term / short-term split on the held buy queue.
      today = Date.current
      long_term_units  = 0.0
      short_term_units = 0.0
      buy_queue.each do |b|
        age = (today - b[:purchase_date]).to_i
        if age >= LT_DAYS
          long_term_units  += b[:qty]
        else
          short_term_units += b[:qty]
        end
      end

      total_buy_amount  = buys_sorted.sum  { |i| i.amount_invested.to_f }
      sale_proceeds     = sells_sorted.sum { |i| i.amount_invested.to_f }
      net_cash_deployed = total_buy_amount - sale_proceeds

      realized_fifo = sale_proceeds - cost_basis_of_sold

      # Weighted-average comparison.
      wavg_buy_price       = buy_qty.positive? ? total_buy_amount / buy_qty : 0.0
      wavg_cost_basis_held = net_qty * wavg_buy_price
      wavg_realized        = sale_proceeds - sell_qty * wavg_buy_price

      is_closed       = net_qty <= QTY_EPSILON
      cost_basis_held = is_closed ? 0.0 : fifo_cost_basis
      cv              = is_closed ? 0.0 : net_qty * current_price.to_f
      unrealized      = cv - cost_basis_held

      avg_buy_price =
        if is_closed
          wavg_buy_price.positive? ? wavg_buy_price : nil
        elsif fifo_held_qty > QTY_EPSILON
          fifo_cost_basis / fifo_held_qty
        else
          nil
        end

      {
        is_closed:         is_closed,
        buy_lots:          buys_sorted.size,
        sell_lots:         sells_sorted.size,
        buy_qty:           buy_qty,
        sell_qty:          sell_qty,
        net_qty:           net_qty,
        total_units:       is_closed ? 0.0 : net_qty,
        long_term_units:   is_closed ? 0.0 : long_term_units,
        short_term_units:  is_closed ? 0.0 : short_term_units,
        avg_buy_price:     avg_buy_price,
        cost_basis_held:   cost_basis_held,
        total_invested:    cost_basis_held,             # alias matching the Holding column
        current_value:     cv,
        unrealized_gain:   unrealized,
        realized_gain:     realized_fifo,
        net_cash_deployed: net_cash_deployed,
        lot_pnl:           lot_pnl,
        lot_breakdown:     lot_breakdown,
        wavg: {
          avg_buy_price:   wavg_buy_price.positive? ? wavg_buy_price : nil,
          cost_basis_held: is_closed ? 0.0 : wavg_cost_basis_held,
          unrealized_gain: is_closed ? 0.0 : cv - wavg_cost_basis_held,
          realized_gain:   wavg_realized
        }
      }
    end
  end
end
