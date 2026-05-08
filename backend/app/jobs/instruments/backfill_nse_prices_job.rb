module Instruments
  # Fetches one trading day of NSE bhavcopy for the supplied tracked-stock id
  # set and upserts into instrument_price_history. Holidays and weekends short-
  # circuit silently inside the service.
  class BackfillNsePricesJob < ApplicationJob
    queue_as :price_backfill

    # NSE archives occasionally return 503 under load; let Sidekiq's exponential
    # backoff sort it out. ActiveJob's default retry covers this when paired
    # with Sidekiq adapter.
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(date_iso, stock_instrument_ids)
      date = Date.parse(date_iso)
      Instruments::PriceBackfillService.nse_for_date(date, stock_instrument_ids)
    end
  end
end
