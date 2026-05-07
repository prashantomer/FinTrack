module Reports
  class PortfolioService
    # Quantities held in `decimal(12, 4)` — anything below this is rounding noise.
    QTY_EPSILON = 0.0001

    def initialize(user)
      @user = user
    end

    def call
      investments = @user.investments.includes(:platform_account, user_instrument: :instrument)
      return empty_result if investments.empty?

      positions = investments.group_by(&:user_instrument_id).map do |_ui_id, lots|
        instrument = lots.first.user_instrument&.instrument
        next nil unless instrument
        position_for(instrument, lots)
      end.compact.sort_by { |p| [ p[:is_closed] ? 1 : 0, -p[:current_value] ] }

      total_invested  = positions.sum { |p| p[:total_invested] }
      current_value   = positions.sum { |p| p[:current_value] }
      unrealized_gain = current_value - total_invested
      realized_gain   = positions.sum { |p| p[:realized_gain] }
      gain_pct        = total_invested > 0 ? (unrealized_gain / total_invested) * 100 : 0

      by_type = positions.group_by { |p| p[:type] }.map do |type, ps|
        {
          type:            type,
          investment_type: type,
          total_invested:  ps.sum { |p| p[:total_invested] },
          current_value:   ps.sum { |p| p[:current_value] },
          unrealized_gain: ps.sum { |p| p[:unrealized_gain] },
          realized_gain:   ps.sum { |p| p[:realized_gain] },
          count:           ps.size
        }
      end.sort_by { |h| -h[:current_value] }

      lots_by_platform = positions.flat_map { |p|
        p[:lots].map { |l| { platform: l[:platform_account_nickname] || "Unknown", position: p } }
      }
      by_platform = lots_by_platform.group_by { |x| x[:platform] }.map do |name, entries|
        positions_in_platform = entries.map { |e| e[:position] }.uniq
        invested = positions_in_platform.sum { |p| p[:total_invested] }
        current  = positions_in_platform.sum { |p| p[:current_value] }
        { platform_name: name, total_invested: invested, current_value: current }
      end.sort_by { |p| -p[:current_value] }

      {
        cost_basis_method:     "fifo",
        total_invested:        total_invested,
        current_value:         current_value,
        unrealized_gain:       unrealized_gain,
        unrealized_gain_pct:   gain_pct,
        realized_gain:         realized_gain,
        total_gain:            unrealized_gain + realized_gain,
        by_type:               by_type,
        by_platform:           by_platform,
        positions:             positions
      }
    end

    private

    def empty_result
      { cost_basis_method: "fifo", total_invested: 0, current_value: 0, unrealized_gain: 0, unrealized_gain_pct: 0,
        realized_gain: 0, total_gain: 0, by_type: [], by_platform: [], positions: [] }
    end

    def position_for(instrument, lots)
      investment_type             = lots.first.investment_type
      current_price, price_source = Holdings::PriceResolver.call(instrument, lots, investment_type)
      stats                       = Holdings::PositionCalculator.call(lots, current_price: current_price, investment_type: investment_type)

      cost_basis_held     = stats[:cost_basis_held]
      unrealized_gain     = stats[:unrealized_gain]
      unrealized_gain_pct = cost_basis_held > 0 ? (unrealized_gain / cost_basis_held) * 100 : 0.0

      platform_names = lots.map { |i| i.platform_account&.nickname }.compact.uniq

      {
        user_instrument_id:    lots.first.user_instrument_id,
        instrument_id:         instrument.id,
        instrument_name:       instrument.name,
        instrument_ticker:     instrument.ticker_symbol,
        instrument_exchange:   instrument.exchange,
        type:                  investment_type,
        platform_accounts:     platform_names,
        total_lots:            lots.count,
        buy_lots:              stats[:buy_lots],
        sell_lots:             stats[:sell_lots],
        is_closed:             stats[:is_closed],
        total_units:           stats[:total_units],
        long_term_units:       stats[:long_term_units],
        short_term_units:      stats[:short_term_units],
        total_invested:        cost_basis_held,
        net_cash_deployed:     stats[:net_cash_deployed],
        avg_buy_price:         stats[:avg_buy_price],
        current_price:         current_price.positive? ? current_price : nil,
        current_price_source:  price_source,
        current_price_at:      instrument.last_price_at,
        current_value:         stats[:current_value],
        unrealized_gain:       unrealized_gain,
        unrealized_gain_pct:   unrealized_gain_pct,
        realized_gain:         stats[:realized_gain],
        folio_number:          derive_folio_number(investment_type, lots),
        wavg:                  stats[:wavg],
        lots:                  lots.sort_by(&:purchase_date).map { |i| lot_json(i, stats[:lot_pnl]) }
      }
    end

    # Per-position folio number for mutual funds: latest buy lot's
    # folio_number, falling back to nil. Stocks don't have folios.
    def derive_folio_number(investment_type, lots)
      return nil unless investment_type == "mutual_fund"
      lots.select(&:buy?)
          .select { |l| l.folio_number.present? }
          .max_by(&:purchase_date)
          &.folio_number
    end

    def lot_json(inv, lot_pnl = {})
      {
        id:                          inv.id,
        trade_type:                  inv.trade_type,
        purchase_date:               inv.purchase_date,
        amount_invested:             inv.amount_invested.to_f,
        current_value:               inv.current_value&.to_f,
        quantity:                    inv.quantity&.to_f,
        units:                       inv.units&.to_f,
        price:                       inv.price&.to_f,
        folio_number:                inv.folio_number,
        platform_account_nickname:   inv.platform_account&.nickname,
        notes:                       inv.notes,
        pnl:                         lot_pnl[inv.id]
      }
    end
  end
end
