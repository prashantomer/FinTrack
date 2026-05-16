namespace :imports do
  desc <<~DESC
    Backfill `result_message` on historical ImportBatch rows.

    Why: the `result_message` column was added so each batch carries a
    human-readable explanation of its outcome (success / re-upload /
    needs_reconciliation / aborted / failed). Batches imported before
    that column existed all have result_message = NULL, so their list
    view looks blank even though the structural counters tell us
    exactly what happened.

    This task walks every batch with result_message IS NULL and
    composes a sensible message from the existing fields (status,
    counters, expected_balance vs current account balance). It does
    NOT touch batches whose result_message is already set.

    Run: bin/rails imports:backfill_result_messages
  DESC
  task backfill_result_messages: :environment do
    scope = ImportBatch.where(result_message: nil)
    total = scope.count
    puts "Found #{total} ImportBatch row#{total == 1 ? '' : 's'} with no result_message."
    next if total.zero?

    updated = 0
    scope.find_each do |batch|
      msg = synthesize_result_message(batch)
      next unless msg

      batch.update_columns(result_message: msg, updated_at: Time.current)
      updated += 1
      printf("  Batch##{batch.id.to_s.rjust(5)}  %-22s  %s\n", batch.status, msg)
    end
    puts
    puts "Backfilled #{updated} of #{total} batches."
  end

  # --- helpers --------------------------------------------------------

  def synthesize_result_message(batch)
    total = batch.total_rows.to_i
    proc_ = batch.processed_rows.to_i
    dup   = batch.duplicate_rows.to_i
    err   = batch.failed_rows.to_i
    ok    = batch.import_records.where(status: "ok").count

    case batch.status
    when "completed"
      completed_message(batch, ok, dup, err)
    when "failed"
      failed_message(batch, ok, dup, err)
    when "needs_reconciliation"
      reconciliation_message(batch, ok, dup)
    when "processing"
      "Was still processing at #{proc_} of #{total} rows when the column was added. Re-run if the batch never completed."
    when "pending"
      "Was pending (never started) when the column was added."
    end
  end

  def completed_message(batch, ok, dup, err)
    # An aborted batch is also stored as :failed, but a completed one with
    # zero :ok rows means every file row deduped against prior history.
    if ok.zero? && dup.positive?
      "Re-upload detected: all #{dup} row#{'s' unless dup == 1} already existed from a prior import. No new transactions added."
    else
      summary_line(ok, dup, err)
    end
  end

  def failed_message(batch, ok, dup, err)
    # Aborts clear processed/duplicate/failed back to 0 and wipe ImportRecord
    # rows. If we see all-zero counters and zero import_records, the batch
    # was almost certainly aborted (manual rollback). Otherwise it was a
    # genuine processing failure that left counters intact.
    record_count = batch.import_records.count
    if proc_zero?(batch) && record_count.zero?
      account = lookup_account(batch)
      if batch.expected_balance && account
        gap = (account.balance.to_f - batch.expected_balance.to_f).round(2)
        "Aborted (historic): file expected ₹#{batch.expected_balance.to_f.round(2)}, " \
          "account at ₹#{account.balance.to_f.round(2)} (gap ₹#{gap}). All imported rows rolled back."
      else
        "Aborted: all imported transactions removed."
      end
    else
      "Failed during processing: #{summary_line(ok, dup, err)}"
    end
  end

  def reconciliation_message(batch, ok, dup)
    account = lookup_account(batch)
    if batch.expected_balance && account
      gap = (account.balance.to_f - batch.expected_balance.to_f).round(2)
      "Final balance ₹#{account.balance.to_f.round(2)} differs from the file's expected " \
        "₹#{batch.expected_balance.to_f.round(2)} (gap ₹#{gap}). Choose how to resolve."
    else
      "Awaiting reconciliation: applied #{ok} row#{'s' unless ok == 1}#{", skipped #{dup}" if dup.positive?}."
    end
  end

  def summary_line(ok, dup, err)
    parts = []
    parts << "#{ok} new transaction#{'s' unless ok == 1} imported"
    parts << "#{dup} duplicate#{'s' unless dup == 1} skipped" if dup.positive?
    parts << "#{err} row#{'s' unless err == 1} failed"        if err.positive?
    "#{parts.join(', ')}."
  end

  def proc_zero?(batch)
    batch.processed_rows.to_i.zero? &&
      batch.duplicate_rows.to_i.zero? &&
      batch.failed_rows.to_i.zero?
  end

  def lookup_account(batch)
    return nil unless batch.linked_account_type && batch.linked_account_id
    klass = batch.linked_account_type == "TermAccount" ? TermAccount : Account
    klass.find_by(id: batch.linked_account_id, user_id: batch.user_id)
  end
end
