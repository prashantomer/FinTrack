require "csv"

module Imports
  # Processes a transaction import batch. The name still says "Csv" — kept
  # for stability — but the job actually accepts CSV, XLS, and XLSX. The
  # source format is decided by file extension and parsed accordingly, then
  # each row flows through the same ProcessTransactionRowService once the
  # active adapter has normalised it to the canonical hash shape.
  class ProcessTransactionCsvJob < ApplicationJob
    queue_as :imports

    def perform(import_batch_id)
      batch = ImportBatch.find(import_batch_id)
      batch.update!(status: :processing)

      rows, adapter = load_rows(batch)
      batch.update!(total_rows: rows.size)

      # Source files like ICICI's xls carry an authoritative running balance;
      # the LAST row's value is what the account should end at. We capture
      # it as the batch's expected_balance and reconcile after processing.
      expected_balance = rows.map { |r| adapter.transform(r, batch: batch)[:balance_after] }.compact.last

      rows.each_with_index do |raw_row, idx|
        normalised = adapter.transform(raw_row, batch: batch)
        result     = Imports::ProcessTransactionRowService.new(batch, normalised, idx).call
        batch.increment!(:duplicate_rows) if result == Imports::ProcessTransactionRowService::DUPLICATE
        batch.increment!(:processed_rows)
      rescue => e
        batch.increment!(:failed_rows)
        batch.increment!(:processed_rows)
        batch.import_records.create!(row_index: idx, status: :error, notes: e.message)
      end

      finalize_with_reconciliation!(batch, expected_balance)
    rescue => e
      Rails.logger.error("ImportBatch #{import_batch_id} (transactions) failed: #{e.message}")
      ImportBatch.find_by(id: import_batch_id)&.update!(status: :failed)
    end

    private

    # After all rows have been processed, compare the computed account balance
    # to the source file's last running balance (`expected_balance`). If they
    # match — or the adapter didn't provide one — mark the batch completed.
    # Otherwise honour the batch's on_balance_mismatch policy.
    def finalize_with_reconciliation!(batch, expected_balance)
      account = batch.linked_account_type && batch.linked_account_id &&
                batch.linked_account_type.safe_constantize&.find_by(
                  id: batch.linked_account_id, user_id: batch.user_id
                )

      if expected_balance.nil? || account.nil?
        batch.update!(status: :completed)
        return
      end

      batch.update!(expected_balance: expected_balance)
      gap = (account.balance.to_f - expected_balance.to_f).round(2)

      if gap.abs < 0.01
        batch.update!(status: :completed)
        return
      end

      case batch.on_balance_mismatch
      when "adjust"
        create_reconciliation_adjustment!(batch, account, expected_balance)
        batch.update!(status: :completed)
      when "fail"
        Imports::AbortBatchService.new(batch).call
      else # "ask"
        # Leave txns + balance in place; the UI shows the gap and lets the
        # user resolve it via POST /imports/:id/resolve.
        batch.update!(status: :needs_reconciliation)
      end
    end

    def create_reconciliation_adjustment!(batch, account, target_balance)
      Accounts::AdjustBalanceService.new(
        batch.user,
        account,
        target_balance: target_balance,
        date:           Date.current,
        description:    "Import reconciliation (batch ##{batch.id})"
      ).call
    end

    # Returns [ rows, adapter ] where rows is an Array of header-keyed hashes
    # (CSV::Row works too — the adapters call .to_h before reading). The
    # adapter is picked from the header signature.
    def load_rows(batch)
      ext = File.extname(batch.file_name.to_s).downcase

      if ext == ".xls" || ext == ".xlsx"
        load_workbook(batch)
      else
        load_csv(batch)
      end
    end

    def load_csv(batch)
      csv = CSV.parse(batch.file.download.force_encoding("UTF-8"),
                      headers:           true,
                      header_converters: :symbol)
      adapter = Imports::TransactionFormatAdapters.for_headers(csv.headers)
      # Materialise into plain hashes so the iteration path matches the xls case.
      rows = csv.map(&:to_h)
      [ rows, adapter ]
    end

    def load_workbook(batch)
      # roo needs a real filesystem path. Stream the blob to a temp file.
      tempfile = Tempfile.new([ "import-", File.extname(batch.file_name.to_s) ], binmode: true)
      tempfile.write(batch.file.download)
      tempfile.flush

      reader  = Imports::TransactionWorkbookReader.new(path: tempfile.path)
      adapter = Imports::TransactionFormatAdapters.for_headers(reader.headers)
      rows    = reader.each_row.map(&:to_h)
      [ rows, adapter ]
    ensure
      tempfile&.close
      tempfile&.unlink
    end
  end
end
