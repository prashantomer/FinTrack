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
        # `txn.destroy` fires Transaction#before_destroy → reverse_balance_delta,
        # which already restores the account balance + writes an audit row
        # ("revert:txn_N"). We just need to walk through and destroy.
        txns.each { |rec| rec.importable&.destroy }
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
  end
end
