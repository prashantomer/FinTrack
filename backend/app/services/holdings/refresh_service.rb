module Holdings
  # Recomputes the cached stats on a Holding row from its underlying Investment
  # lots. Single source of truth for "what's my position?" math via
  # {Holdings::PositionCalculator} (FIFO) and {Holdings::PriceResolver}.
  #
  # Usage:
  #   Holdings::RefreshService.new(user, user_instrument_id, platform_account_id).call
  #   Holdings::RefreshService.refresh_for_user_instrument(user, user_instrument_id)
  #   Holdings::RefreshService.refresh_all_for(user)
  class RefreshService
    def self.refresh_all_for(user)
      pairs = user.investments.distinct.pluck(:user_instrument_id, :platform_account_id)
      pairs.each do |ui_id, pa_id|
        next if ui_id.nil? || pa_id.nil?
        new(user, ui_id, pa_id).call
      end
    end

    # Refresh every holding that belongs to a single user_instrument across all
    # the user's platform accounts. Used after a folio_number bulk update.
    def self.refresh_for_user_instrument(user, user_instrument_id)
      pa_ids = user.investments.where(user_instrument_id: user_instrument_id)
                   .distinct.pluck(:platform_account_id).compact
      pa_ids.each { |pa_id| new(user, user_instrument_id, pa_id).call }
    end

    attr_reader :user, :user_instrument_id, :platform_account_id

    def initialize(user, user_instrument_id, platform_account_id)
      @user                = user
      @user_instrument_id  = user_instrument_id
      @platform_account_id = platform_account_id
    end

    def call
      lots = user.investments
                 .includes(user_instrument: :instrument)
                 .where(user_instrument_id: user_instrument_id, platform_account_id: platform_account_id)
                 .to_a
      return destroy_if_empty if lots.empty?

      investment_type = lots.first.investment_type
      instrument      = lots.first.user_instrument&.instrument
      current_price, = Holdings::PriceResolver.call(instrument, lots, investment_type)
      stats          = Holdings::PositionCalculator.call(lots, current_price: current_price, investment_type: investment_type)

      holding = find_or_initialize_holding(lots)
      holding.assign_attributes(
        buy_lots:           stats[:buy_lots],
        sell_lots:          stats[:sell_lots],
        total_units:        stats[:total_units],
        long_term_units:    stats[:long_term_units],
        short_term_units:   stats[:short_term_units],
        avg_buy_price:      stats[:avg_buy_price],
        total_invested:     stats[:total_invested],
        current_value:      stats[:current_value],
        unrealized_gain:    stats[:unrealized_gain],
        realized_gain:      stats[:realized_gain],
        is_closed:          stats[:is_closed],
        last_calculated_at: Time.current
      )
      holding.save!

      persist_lot_pnl(lots, stats[:lot_pnl] || {})

      holding
    end

    private

    # Write per-lot P&L back onto each Investment row. Uses `update_columns`
    # to skip validations and the `after_save_commit` callback, otherwise we'd
    # re-enqueue a Holdings::RefreshJob for every lot we touch and loop.
    #
    # BUY lots get `lot_unrealized_gain`; SELL lots get `lot_realized_gain`.
    # Lots that the FIFO walk fully consumed (and no remainder) end up with
    # both columns nil — see Investment#pnl helpers for read-side handling.
    def persist_lot_pnl(lots, lot_pnl_map)
      now = Time.current
      lots.each do |inv|
        entry = lot_pnl_map[inv.id]
        if entry
          if inv.buy?
            next if equal_to_two?(inv.lot_unrealized_gain, entry[:value]) && inv.lot_pnl_at
            inv.update_columns(
              lot_unrealized_gain: entry[:value],
              lot_realized_gain:   nil,
              lot_pnl_at:          now
            )
          else
            next if equal_to_two?(inv.lot_realized_gain, entry[:value]) && inv.lot_pnl_at
            inv.update_columns(
              lot_realized_gain:   entry[:value],
              lot_unrealized_gain: nil,
              lot_pnl_at:          now
            )
          end
        elsif inv.lot_unrealized_gain.present? || inv.lot_realized_gain.present?
          # Lot was previously tracked but is no longer in the FIFO map (e.g.
          # a buy lot that's been fully consumed). Clear it.
          inv.update_columns(lot_unrealized_gain: nil, lot_realized_gain: nil, lot_pnl_at: now)
        end
      end
    end

    # Compare to two-decimal precision to avoid spurious writes when float
    # round-trip introduces sub-cent drift.
    def equal_to_two?(a, b)
      return false if a.nil? || b.nil?
      a.to_d.round(2) == b.to_d.round(2)
    end

    def destroy_if_empty
      Holding.where(user_id: user.id,
                    user_instrument_id: user_instrument_id,
                    platform_account_id: platform_account_id).destroy_all
      nil
    end

    def find_or_initialize_holding(lots)
      ui_type = lots.first.investment_type
      sti     = (ui_type == "stock") ? "EquityHolding" : "Folio"
      klass   = sti.constantize

      holding = klass.find_or_initialize_by(
        user_id: user.id,
        user_instrument_id: user_instrument_id,
        platform_account_id: platform_account_id
      )
      if sti == "Folio"
        latest_with_folio = lots.select { |i| i.folio_number.present? }.max_by(&:purchase_date)
        # Placeholder so Folio's presence validation doesn't fail when imports
        # came in without a folio_number — user can correct later.
        holding.folio_number = latest_with_folio&.folio_number || "(unset)"
      end
      holding
    end
  end
end
