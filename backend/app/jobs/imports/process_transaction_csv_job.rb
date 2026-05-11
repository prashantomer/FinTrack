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

      normalised_rows = rows.map { |r| adapter.transform(r, batch: batch) }

      # Source files like ICICI's xls carry an authoritative running balance;
      # the LAST row's value is what the account should end at. We capture
      # it as the batch's expected_balance and reconcile after processing.
      expected_balance = normalised_rows.map { |r| r[:balance_after] }.compact.last

      # If the target account is brand-new (zero balance, no transactions)
      # and the adapter can derive an opening balance from the source file,
      # materialise it as an adjustment Transaction. The ledger then stays
      # continuous and the tail-end reconciliation has nothing to do.
      seed_opening_balance_if_blank!(batch, adapter, normalised_rows)

      normalised_rows.each_with_index do |normalised, idx|
        result = Imports::ProcessTransactionRowService.new(batch, normalised, idx).call
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

    # Run the anchor row through the same dedup ladder used during row
    # processing, so the seed check stays consistent with whatever the
    # adapter's format calls a duplicate. Returns false if the anchor's
    # date/type/amount are malformed — the row will then fail in the
    # main loop with a clear error, but seeding shouldn't pre-empt that.
    def anchor_is_duplicate?(batch, account, anchor_row)
      date = Imports::ProcessTransactionRowService.parse_date!(anchor_row[:date])
      Imports::ProcessTransactionRowService.duplicate_for(
        user:           batch.user,
        date:           date,
        amount:         anchor_row[:amount].to_f,
        type:           anchor_row[:type].to_s.downcase,
        linked_account: account,
        bank_ref:       anchor_row[:bank_ref].presence
      ).present?
    rescue
      false
    end

    def seed_opening_balance_if_blank!(batch, adapter, normalised_rows)
      return unless batch.linked_account_type == "Account" && batch.linked_account_id
      account = Account.find_by(id: batch.linked_account_id, user_id: batch.user_id)
      return unless account
      return unless account.balance.to_f.zero?
      return if Transaction.exists?(
        linked_account_type: "Account",
        linked_account_id:   account.id
      )

      seed = adapter.opening_balance(normalised_rows)
      return unless seed && seed.amount.to_f > 0

      # If the adapter back-calculated the opening from an anchor row, that
      # row must actually land in the ledger. Run it through the same dedup
      # ladder the row-processor uses — however the active adapter's format
      # identifies a duplicate (bank_ref for ICICI, structural fallback for
      # canonical CSV, future bank conventions) — and bail if it would be
      # treated as a duplicate. Otherwise the row gets :skipped while the
      # seed is applied and the ledger ends up off by that delta.
      if seed.anchor_row && anchor_is_duplicate?(batch, account, seed.anchor_row)
        return
      end

      opening_txn = Transaction.create!(
        user:                account.user,
        source:              "manual",
        amount:              seed.amount,
        transaction_type:    "credit",
        date:                account.open_date,
        description:         "Opening balance (import ##{batch.id})",
        tags:                [ "adjustment", "opening" ],
        linked_account_type: "Account",
        linked_account_id:   account.id
      )

      # Tie the seed to the batch via ImportRecord so AbortBatchService
      # walks it on rollback. row_index -1 distinguishes it from real
      # file rows (which are 0-indexed); the notes line keeps it obvious
      # in the UI's import detail view.
      batch.import_records.create!(
        importable: opening_txn,
        row_index:  -1,
        status:     :ok,
        notes:      "Opening balance seed (back-calculated from first row)"
      )
    end

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
