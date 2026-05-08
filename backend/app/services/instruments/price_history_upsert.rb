module Instruments
  # Idempotent batch upsert into instrument_price_history. Hits the existing
  # uq_instr_price_history_per_day unique index so same-day re-runs overwrite
  # the price; created_at survives, updated_at is auto-bumped by Rails.
  module PriceHistoryUpsert
    BATCH_SIZE = 1_000

    module_function

    def call(rows)
      return 0 if rows.empty?
      rows.each_slice(BATCH_SIZE).sum do |chunk|
        InstrumentPriceHistory.upsert_all(
          chunk,
          unique_by:   :uq_instr_price_history_per_day,
          update_only: %i[price source]
        )
        chunk.size
      end
    end
  end
end
