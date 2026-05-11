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

    def call
      ActiveRecord::Base.transaction do
        txns = @batch.import_records.where(importable_type: "Transaction").includes(:importable)
        txns.each do |rec|
          txn = rec.importable
          next unless txn

          reverse_balance!(txn)
          txn.destroy
        end
        @batch.import_records.delete_all
        @batch.update!(
          status:          :failed,
          processed_rows:  0,
          duplicate_rows:  0,
          failed_rows:     0
        )
      end
      @batch
    end

    private

    # Restores the account balance to what it was before this transaction
    # ran. Uses the same `audit_comment` pattern as the original write so
    # the audit log shows a clean pair: "txn:N" (apply) → "abort:N" (undo).
    def reverse_balance!(txn)
      acct = txn.linked_account
      return if acct.nil?
      return if acct.is_a?(TermAccount) && acct.fd?

      delta = txn.credit? ? -txn.amount.to_f : txn.amount.to_f
      Audited.audit_class.as_user(txn.user) do
        acct.audit_comment = "abort:txn_#{txn.id}"
        acct.update!(balance: acct.balance.to_f + delta)
      end
    end
  end
end
