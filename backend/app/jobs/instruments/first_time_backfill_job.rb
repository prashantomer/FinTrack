module Instruments
  # Coordinator job that enqueues the per-day NSE / per-range AMFI backfill
  # jobs for a single newly-tracked instrument. Lifted off the request
  # thread so /track endpoint stays snappy even when ~250 day-jobs need to
  # land in the queue.
  class FirstTimeBackfillJob < ApplicationJob
    queue_as :price_backfill

    def perform(instrument_id)
      instrument = Instrument.find_by(id: instrument_id)
      return unless instrument
      Instruments::PriceBackfillScheduler.enqueue_for(instrument)
    end
  end
end
