module Instruments
  # Read-side facade for the four `/instruments/:id/{position,lots,transactions,price-history}`
  # endpoints. Wraps the existing per-instrument computations so the controller
  # stays thin and the per-call surface is stable.
  #
  # Always scoped to (user, instrument). The gate (Instruments::ProfileGate)
  # is the caller's responsibility — this service assumes access is allowed.
  class ProfileService
    DEFAULT_TX_LIMIT      = 50
    MAX_TX_LIMIT          = 200
    DEFAULT_HISTORY_DAYS  = 90
    MAX_HISTORY_DAYS      = 1825 # ~5 years
    EMPTY_POSITION        = { is_closed: true, total_units: 0, total_lots: 0, buy_lots: 0, sell_lots: 0 }.freeze

    attr_reader :user, :instrument

    def initialize(user, instrument)
      @user       = user
      @instrument = instrument
    end

    # Single position payload (same shape as one row of /reports/portfolio).
    # Returns nil-shaped EMPTY_POSITION when the user holds nothing — keeps
    # the JSON contract stable so the frontend can branch on `is_closed`.
    def position
      lots = position_lots
      return EMPTY_POSITION.merge(instrument_id: instrument.id, instrument_name: instrument.name, lots: []) if lots.empty?
      ::Reports::PortfolioService.build_position(instrument, lots)
    end

    # Per-lot payload only (same shape ProfileService#position would emit
    # under :lots). Useful when a caller wants the lot ledger without the
    # surrounding stats.
    def lots
      pos = position
      pos.is_a?(Hash) ? Array(pos[:lots]) : []
    end

    # Transactions linked to this instrument. Read-only; uses the existing
    # TransactionSerializer-friendly Transaction columns directly.
    def transactions(limit: DEFAULT_TX_LIMIT)
      capped = limit.to_i.clamp(1, MAX_TX_LIMIT)
      user.transactions
          .where(instrument_id: instrument.id)
          .order(date: :desc, id: :desc)
          .limit(capped)
    end

    # [{ date: Date, price: BigDecimal, source: String }] over the requested
    # window (cap 1..1825 days). Ordered ascending so charts can plot directly.
    def price_history(days: DEFAULT_HISTORY_DAYS)
      capped = days.to_i.clamp(1, MAX_HISTORY_DAYS)
      since  = Date.current - capped.days
      ::InstrumentPriceHistory
        .for_instrument(instrument.id)
        .where("price_date >= ?", since)
        .order(:price_date)
    end

    private

    # All of the user's investment lots that touch this instrument, eager-loaded
    # to match what PortfolioService.build_position expects (platform_account
    # nicknames, the user_instrument → instrument chain).
    def position_lots
      user.investments
          .joins(:user_instrument)
          .where(user_instruments: { instrument_id: instrument.id })
          .includes(:platform_account, user_instrument: :instrument)
          .to_a
    end
  end
end
