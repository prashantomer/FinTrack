module Instruments
  # Fetches an AMFI historical-NAV range (typically a 30-day chunk) for the
  # supplied tracked-MF ISIN set and upserts into instrument_price_history.
  class BackfillAmfiNavsJob < ApplicationJob
    queue_as :price_backfill

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(from_iso, to_iso, mf_isins)
      from_date = Date.parse(from_iso)
      to_date   = Date.parse(to_iso)
      Instruments::PriceBackfillService.amfi_for_range(from_date, to_date, mf_isins)
    end
  end
end
