module Reports
  class PortfolioService
    def initialize(user)
      @user = user
    end

    def call
      investments = @user.investments.includes(:user_instrument, :platform_account)
      return empty_result if investments.empty?

      by_instrument = investments.group_by(&:user_instrument_id)

      positions = by_instrument.map do |ui_id, lots|
        ui         = lots.first.user_instrument
        instrument = ui&.instrument
        next nil unless instrument

        investment_type = lots.first.investment_type
        total_invested  = lots.sum { |i| i.amount_invested.to_f }
        total_current   = lots.sum { |i| (i.current_value || i.amount_invested).to_f }
        unrealized_gain = total_current - total_invested
        gain_pct        = total_invested > 0 ? (unrealized_gain / total_invested) * 100 : 0
        platform_names  = lots.map { |i| i.platform_account&.nickname }.compact.uniq

        total_units, avg_buy = if investment_type == "stock"
          qty = lots.sum { |i| i.quantity.to_f }
          avg = qty > 0 ? lots.sum { |i| i.quantity.to_f * i.buy_price.to_f } / qty : nil
          [ qty > 0 ? qty : nil, avg ]
        else
          u = lots.sum { |i| i.units.to_f }
          avg = u > 0 ? lots.sum { |i| i.units.to_f * i.nav_at_purchase.to_f } / u : nil
          [ u > 0 ? u : nil, avg ]
        end

        {
          user_instrument_id:    ui_id,
          instrument_name:       instrument.name,
          instrument_ticker:     instrument.ticker_symbol,
          instrument_exchange:   instrument.exchange,
          type:                  lots.first.investment_type,
          platform_accounts:     platform_names,
          total_lots:            lots.count,
          total_units:           total_units,
          total_invested:        total_invested,
          avg_buy_price:         avg_buy,
          current_value:         total_current,
          unrealized_gain:       unrealized_gain,
          unrealized_gain_pct:   gain_pct,
          lots:                  lots.sort_by(&:purchase_date).map { |i| lot_json(i) }
        }
      end.compact.sort_by { |p| -p[:current_value] }

      total_invested  = positions.sum { |p| p[:total_invested] }
      current_value   = positions.sum { |p| p[:current_value] }
      unrealized_gain = current_value - total_invested
      gain_pct        = total_invested > 0 ? (unrealized_gain / total_invested) * 100 : 0

      by_type = positions.group_by { |p| p[:type] }.map do |type, ps|
        {
          type:            type,
          investment_type: type,
          total_invested:  ps.sum { |p| p[:total_invested] },
          current_value:   ps.sum { |p| p[:current_value] },
          unrealized_gain: ps.sum { |p| p[:unrealized_gain] },
          count:           ps.size
        }
      end.sort_by { |h| -h[:current_value] }

      by_platform = investments.group_by { |i| i.platform_account&.nickname || "Unknown" }.map do |name, invs|
        invested = invs.sum { |i| i.amount_invested.to_f }
        current  = invs.sum { |i| (i.current_value || i.amount_invested).to_f }
        { platform_name: name, total_invested: invested, current_value: current }
      end.sort_by { |p| -p[:current_value] }

      {
        total_invested:      total_invested,
        current_value:       current_value,
        unrealized_gain:     unrealized_gain,
        unrealized_gain_pct: gain_pct,
        by_type:             by_type,
        by_platform:         by_platform,
        positions:           positions
      }
    end

    private

    def empty_result
      { total_invested: 0, current_value: 0, unrealized_gain: 0, unrealized_gain_pct: 0,
        by_type: [], by_platform: [], positions: [] }
    end

    def lot_json(inv)
      {
        id:                          inv.id,
        purchase_date:               inv.purchase_date,
        amount_invested:             inv.amount_invested.to_f,
        current_value:               inv.current_value&.to_f,
        quantity:                    inv.quantity&.to_f,
        buy_price:                   inv.buy_price&.to_f,
        folio_number:                inv.folio_number,
        units:                       inv.units&.to_f,
        nav_at_purchase:             inv.nav_at_purchase&.to_f,
        platform_account_nickname:   inv.platform_account&.nickname,
        notes:                       inv.notes
      }
    end
  end
end
