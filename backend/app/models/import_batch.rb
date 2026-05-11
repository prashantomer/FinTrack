# == Schema Information
#
# Table name: import_batches
#
#  id                  :bigint           not null, primary key
#  duplicate_rows      :integer          default(0), not null
#  expected_balance    :decimal(14, 2)
#  failed_rows         :integer          default(0), not null
#  file_name           :string           not null
#  import_number       :integer          not null
#  import_type         :string           not null
#  import_version      :integer          default(1), not null
#  linked_account_type :string
#  on_balance_mismatch :string           default("ask"), not null
#  processed_rows      :integer          default(0), not null
#  result_message      :text
#  status              :string           default("pending"), not null
#  total_rows          :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  linked_account_id   :bigint
#  sidekiq_job_id      :string
#  user_id             :bigint           not null
#
# Indexes
#
#  idx_import_batches_user_id_import_number  (user_id,import_number) UNIQUE
#  idx_import_batches_version                (user_id,import_type,import_version) UNIQUE
#  index_import_batches_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class ImportBatch < ApplicationRecord
  belongs_to :user
  has_many   :import_records, dependent: :destroy
  has_one_attached :file

  enum :import_type, { investments: "investments", transactions: "transactions", term_accounts: "term_accounts" }, validate: true
  enum :status,      { pending: "pending", processing: "processing",
                       completed: "completed", failed: "failed",
                       # All rows imported but final balance doesn't match the
                       # source file's running balance. Awaiting user choice:
                       # create an adjustment txn (resolve→adjust) or abort
                       # the batch (resolve→abort).
                       needs_reconciliation: "needs_reconciliation" }, validate: true

  # User's policy when the source file's running balance disagrees with the
  # computed account balance post-import:
  #   ask    → pause with status "needs_reconciliation" and surface the gap
  #   adjust → silently create an adjustment txn to absorb the gap
  #   fail   → roll the entire batch back
  enum :on_balance_mismatch, { ask: "ask", adjust: "adjust", fail: "fail" }, validate: true, prefix: :reconcile

  validates :import_type, :status, :file_name, presence: true

  before_create :set_import_version
  before_create :set_import_number

  def progress_pct
    return 0 if total_rows.zero?
    (processed_rows * 100.0 / total_rows).round
  end

  private

  def set_import_version
    max = user.import_batches
              .where(import_type: import_type)
              .maximum(:import_version) || 0
    self.import_version = max + 1
  end

  # Friendly global per-user sequence number — what the UI shows as
  # "Import #N". Distinct from `import_version` (per-type) so users can
  # refer to "import #42" unambiguously across investments/transactions/etc.
  def set_import_number
    self.import_number ||= (user.import_batches.maximum(:import_number) || 0) + 1
  end
end
