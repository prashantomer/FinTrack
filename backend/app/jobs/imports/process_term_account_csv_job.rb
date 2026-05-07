require "csv"

module Imports
  class ProcessTermAccountCsvJob < ApplicationJob
    queue_as :imports

    def perform(import_batch_id)
      batch = ImportBatch.find(import_batch_id)
      batch.update!(status: :processing)

      rows = CSV.parse(batch.file.download.force_encoding("UTF-8"), headers: true, header_converters: :symbol)
      batch.update!(total_rows: rows.count)

      rows.each_with_index do |row, idx|
        Imports::ProcessTermAccountRowService.new(batch, row, idx).call
        batch.increment!(:processed_rows)
      rescue => e
        batch.increment!(:failed_rows)
        batch.increment!(:processed_rows)
        batch.import_records.create!(row_index: idx, status: :error, notes: e.message)
      end

      batch.update!(status: :completed)
    rescue => e
      Rails.logger.error("ImportBatch #{import_batch_id} (term_accounts) failed: #{e.message}")
      ImportBatch.find_by(id: import_batch_id)&.update!(status: :failed)
    end
  end
end
