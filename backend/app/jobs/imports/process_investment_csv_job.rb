require "csv"

module Imports
  class ProcessInvestmentCsvJob < ApplicationJob
    queue_as :imports

    def perform(import_batch_id)
      batch = ImportBatch.find(import_batch_id)
      batch.update!(status: :processing)

      rows = CSV.parse(batch.file.download.force_encoding("UTF-8"), headers: true, header_converters: :symbol)
      batch.update!(total_rows: rows.count)

      adapter = Imports::InvestmentFormatAdapters.for_headers(rows.headers)

      # Per-row Investment commits would each enqueue Holdings::RefreshJob.
      # Suppress that and enqueue a single full-user sweep at the end — much
      # cheaper for hundred-row imports.
      Current.skip_holding_refresh = true

      rows.each_with_index do |row, idx|
        begin
          normalized = adapter.transform(row.to_h)
          result = Imports::ProcessInvestmentRowService.new(batch, normalized, idx).call
          batch.increment!(:duplicate_rows) if result == Imports::ProcessInvestmentRowService::DUPLICATE
          batch.increment!(:processed_rows)
        rescue => e
          batch.increment!(:failed_rows)
          batch.increment!(:processed_rows)
          batch.import_records.create!(
            row_index: idx,
            status:    :error,
            notes:     e.message
          )
        end
      end

      batch.update!(status: :completed)
    rescue => e
      Rails.logger.error("ImportBatch #{import_batch_id} failed: #{e.message}")
      ImportBatch.find_by(id: import_batch_id)&.update!(status: :failed)
    ensure
      Current.skip_holding_refresh = false
      Holdings::RefreshJob.perform_later(batch.user_id) if batch
    end
  end
end
