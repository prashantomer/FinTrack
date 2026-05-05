class ImportBatch < ApplicationRecord
  belongs_to :user
  has_many   :import_records, dependent: :destroy

  enum :import_type, { investments: "investments", transactions: "transactions", term_accounts: "term_accounts" }, validate: true
  enum :status,      { pending: "pending", processing: "processing",
                       completed: "completed", failed: "failed" }, validate: true

  validates :import_type, :status, :file_name, :raw_csv, presence: true

  before_create :set_import_version

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
end
