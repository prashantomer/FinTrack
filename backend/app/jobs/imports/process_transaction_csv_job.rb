require "csv"

module Imports
  # Processes a transaction import batch. The name still says "Csv" — kept
  # for stability — but the job actually accepts CSV, XLS, and XLSX. The
  # source format is decided by file extension and parsed accordingly, then
  # each row flows through the same ProcessTransactionRowService once the
  # active adapter has normalised it to the canonical hash shape.
  class ProcessTransactionCsvJob < ApplicationJob
    queue_as :imports

    # Anything within this rupee threshold of `expected_balance` is treated
    # as a perfect match. Lower than this is sub-paisa floating-point noise
    # that can creep in from the bank file's decimal serialisation.
    BALANCE_GAP_TOLERANCE = 0.01

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
        wrapped = Imports::Error.wrap(e)
        batch.increment!(:failed_rows)
        batch.increment!(:processed_rows)
        batch.import_records.create!(
          row_index: idx,
          status:    :error,
          notes:     "[#{wrapped.code}] #{wrapped.message}"
        )
      end

      finalize_with_reconciliation!(batch, expected_balance)
    rescue => e
      wrapped = Imports::Error.wrap(e, code: :file_parse_failure)
      Rails.logger.error("ImportBatch #{import_batch_id} (transactions) failed: [#{wrapped.code}] #{wrapped.message}")
      ImportBatch.find_by(id: import_batch_id)&.update!(
        status:         :failed,
        result_message: "Import failed [#{wrapped.code}]: #{wrapped.message.truncate(280)}"
      )
    end

    private

    def seed_opening_balance_if_blank!(batch, adapter, normalised_rows)
      account = resolve_blank_seed_target(batch)
      return unless account

      seed = adapter.opening_balance(normalised_rows)
      return unless seed && seed.amount.to_f > 0

      anchor_date = parse_anchor_date(seed.anchor_row)

      # If the adapter back-calculated the opening from an anchor row, the
      # row must actually land in the ledger. Run it through the same dedup
      # ladder the row-processor uses, so the seed check stays consistent
      # however the active adapter identifies duplicates. If the row would
      # be skipped, applying the seed would leave the account off by its
      # delta — bail out.
      if seed.anchor_row && anchor_date && anchor_is_duplicate?(batch, account, seed.anchor_row, anchor_date)
        return
      end

      # Park the seed on the first imported row's date (not account.open_date
      # — they're commonly different, e.g. an account opened in 2016
      # receiving a 2022-23 statement). The seed represents "whatever
      # balance existed just before this statement starts", so dating it
      # on row 0's date keeps the ledger chronological. The model
      # validator forbids date < open_date, so clamp up if the file's
      # earliest row somehow predates the account.
      seed_date = anchor_date || account.open_date
      seed_date = account.open_date if seed_date < account.open_date

      opening_txn = Transaction.create!(
        user:                account.user,
        source:              "manual",
        amount:              seed.amount,
        transaction_type:    "credit",
        date:                seed_date,
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

    # Returns the Account eligible for an opening-balance seed, or nil if
    # the batch isn't seedable (wrong target type, account missing,
    # account already has balance, or pre-existing transactions).
    def resolve_blank_seed_target(batch)
      return nil unless batch.linked_account_type == "Account" && batch.linked_account_id
      account = Account.find_by(id: batch.linked_account_id, user_id: batch.user_id)
      return nil unless account
      return nil unless account.balance.to_f.zero?
      return nil if Transaction.exists?(linked_account_type: "Account", linked_account_id: account.id)
      account
    end

    def parse_anchor_date(anchor_row)
      return nil unless anchor_row
      Imports::ProcessTransactionRowService.parse_date!(anchor_row[:date])
    rescue Imports::Error
      nil
    end

    def anchor_is_duplicate?(batch, account, anchor_row, anchor_date)
      Imports::ProcessTransactionRowService.duplicate_for(
        user:           batch.user,
        date:           anchor_date,
        amount:         anchor_row[:amount].to_f,
        type:           anchor_row[:type].to_s.downcase,
        linked_account: account,
        bank_ref:       anchor_row[:bank_ref].presence
      ).present?
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

      ok_rows   = batch.import_records.where(status: "ok").count
      dup_rows  = batch.duplicate_rows.to_i
      err_rows  = batch.failed_rows.to_i

      if expected_balance.nil? || account.nil?
        batch.update!(status: :completed, result_message: summary_message(ok_rows, dup_rows, err_rows))
        return
      end

      batch.update!(expected_balance: expected_balance)

      # Re-upload of a previously-imported statement: every row dedups,
      # nothing actually lands on the account. Comparing the account's
      # current balance (which reflects ALL history — other years,
      # adjustments, transfers) against this single file's running-balance
      # terminus would always flag a "mismatch" because the two numbers
      # describe different scopes. Mark completed and move on; there's
      # nothing to reconcile.
      if ok_rows.zero?
        batch.update!(
          status:         :completed,
          result_message: "Re-upload detected: all #{dup_rows} rows already in your ledger from a prior import. No new transactions added."
        )
        return
      end

      gap = (account.balance.to_f - expected_balance.to_f).round(2)

      if gap.abs < BALANCE_GAP_TOLERANCE
        batch.update!(status: :completed, result_message: summary_message(ok_rows, dup_rows, err_rows))
        return
      end

      gap_msg = "Final balance ₹#{account.balance.to_f.round(2)} differs from the file's expected ₹#{expected_balance.to_f.round(2)} (gap ₹#{gap})."

      case batch.on_balance_mismatch
      when "adjust"
        create_reconciliation_adjustment!(batch, account, expected_balance)
        batch.update!(
          status:         :completed,
          result_message: "#{summary_message(ok_rows, dup_rows, err_rows)} #{gap_msg} Auto-resolved by creating an adjustment transaction."
        )
      when "fail"
        Imports::AbortBatchService.new(batch).call(reason: "Balance mismatch: #{gap_msg}")
      else # "ask"
        # Leave txns + balance in place; the UI shows the gap and lets the
        # user resolve it via POST /imports/:id/resolve.
        batch.update!(
          status:         :needs_reconciliation,
          result_message: "#{gap_msg} Choose how to resolve."
        )
      end
    end

    # Compose a short success line summarising what changed.
    def summary_message(ok_rows, dup_rows, err_rows)
      parts = []
      parts << "#{ok_rows} new transaction#{'s' unless ok_rows == 1} imported"
      parts << "#{dup_rows} duplicate#{'s' unless dup_rows == 1} skipped" if dup_rows > 0
      parts << "#{err_rows} row#{'s' unless err_rows == 1} failed"        if err_rows > 0
      "#{parts.join(', ')}."
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
