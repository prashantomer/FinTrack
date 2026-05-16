module Imports
  # Rolls an ImportBatch back: deletes every Transaction the batch created,
  # reverses each one's balance impact on the linked account so the audit
  # trail stays consistent, and marks the batch as :failed.
  #
  # Used when:
  #   - The batch was uploaded with on_balance_mismatch="fail" and the
  #     post-import balance doesn't match the source file.
  #   - The user opts to abort a "needs_reconciliation" batch via the UI.
  class AbortBatchService
    def initialize(batch)
      @batch = batch
    end

    def call(reason: nil)
      ActiveRecord::Base.transaction do
        # CRITICAL: only walk :ok rows. A :skipped ImportRecord's `importable`
        # is the pre-existing Transaction the duplicate matched (registered
        # by ProcessTransactionRowService#register_duplicate so the UI can
        # link to it). Destroying those would delete real history from
        # prior imports / manual entries and reverse their balance impact —
        # the abort would then drag the account balance well past zero.
        # :error rows have no importable, so they're harmless either way,
        # but the explicit filter keeps the intent obvious.
        txns = @batch.import_records
                     .where(status: "ok", importable_type: "Transaction")
                     .includes(:importable)

        # Capture txn ids + affected account ids BEFORE destroy so we can
        # erase the audit trail the import + abort left behind. Aborting
        # should look as if the import never happened — without this, the
        # account audit log shows the "txn:N" create paired with a
        # "revert:txn_N" reversal, which is just noise.
        affected_txn_ids     = txns.map { |rec| rec.importable&.id }.compact
        affected_account_ids = txns.filter_map { |rec|
          t = rec.importable
          t && t.linked_account_type == "Account" ? t.linked_account_id : nil
        }.uniq

        # `txn.destroy` fires Transaction#before_destroy → reverse_balance_delta,
        # which restores the account balance + writes an audit row
        # ("revert:txn_N"). We just need to walk through and destroy.
        txns.each { |rec| rec.importable&.destroy }

        purge_audit_trail!(affected_account_ids, affected_txn_ids)

        @batch.import_records.delete_all
        @batch.update!(
          status:          :failed,
          processed_rows:  0,
          duplicate_rows:  0,
          failed_rows:     0,
          result_message:  reason.presence || "Aborted: all imported transactions removed and balance restored."
        )
      end
      @batch
    end

    private

    # Erase the import + abort audit churn on each affected account. We
    # match on the comment strings the Transaction callbacks write:
    #   - "txn:<id>"        — written on create (apply_balance_delta)
    #   - "revert:txn_<id>" — written on destroy (reverse_balance_delta)
    # for every transaction the abort just destroyed.
    def purge_audit_trail!(account_ids, txn_ids)
      return if account_ids.empty? || txn_ids.empty?

      comments = txn_ids.flat_map { |id| [ "txn:#{id}", "revert:txn_#{id}" ] }
      Audited::Audit.where(
        auditable_type: "Account",
        auditable_id:   account_ids,
        comment:        comments
      ).delete_all
    end
  end
end
