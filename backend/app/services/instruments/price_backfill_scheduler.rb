module Instruments
  # Decides + enqueues per-instrument backfill jobs on first-track. Different
  # from the rake task `instruments:backfill_prices`, which fans out across
  # the entire tracked set; this one is scoped to a single instrument and
  # is meant to fire from `TrackService` when a user subscribes for the
  # very first time.
  #
  # Skip logic:
  #   - For NSE stocks, we plug into the (instrument_id, price_date) unique
  #     index and only enqueue day-jobs for dates we don't already have.
  #     This matters because the *daily* PriceFetchService writes for the
  #     whole catalogue, so an instrument that's been in the catalogue
  #     since before the user tracked it may already have weeks/months of
  #     coverage. Skipping known dates avoids re-pulling those bhavcopies.
  #   - For AMFI MFs, we don't have a cheap per-date probe (the portal
  #     endpoint is date-range based), so we just enqueue all 30-day chunks
  #     and rely on the upsert to dedupe.
  module PriceBackfillScheduler
    DAYS = 365

    module_function

    def enqueue_for(instrument)
      return :unsupported_type unless %w[stock mutual_fund].include?(instrument.investment_type)

      end_date   = Date.current
      start_date = end_date - DAYS

      case instrument.investment_type
      when "stock"        then enqueue_nse(instrument, start_date, end_date)
      when "mutual_fund"  then enqueue_amfi(instrument, start_date, end_date)
      end
    end

    def enqueue_nse(instrument, start_date, end_date)
      return :missing_ticker if instrument.ticker_symbol.blank?

      existing = InstrumentPriceHistory
                   .where(instrument_id: instrument.id, price_date: start_date..end_date)
                   .pluck(:price_date).to_set

      enqueued = 0
      (start_date..end_date).each do |d|
        next if d.saturday? || d.sunday?
        next if existing.include?(d)
        BackfillNsePricesJob.perform_later(d.iso8601, [ instrument.id ])
        enqueued += 1
      end
      { kind: :nse, instrument_id: instrument.id, enqueued: enqueued, already_covered: existing.size }
    end

    def enqueue_amfi(instrument, start_date, end_date)
      return :missing_isin if instrument.isin.blank?

      enqueued = 0
      cursor = start_date
      while cursor <= end_date
        chunk_end = [ cursor + 29, end_date ].min
        BackfillAmfiNavsJob.perform_later(cursor.iso8601, chunk_end.iso8601, [ instrument.isin ])
        cursor = chunk_end + 1
        enqueued += 1
      end
      { kind: :amfi, instrument_id: instrument.id, enqueued: enqueued }
    end
  end
end
