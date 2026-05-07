# == Schema Information
#
# Table name: import_batches
#
#  id             :bigint           not null, primary key
#  duplicate_rows :integer          default(0), not null
#  failed_rows    :integer          default(0), not null
#  file_name      :string           not null
#  import_type    :string           not null
#  import_version :integer          default(1), not null
#  processed_rows :integer          default(0), not null
#  status         :string           default("pending"), not null
#  total_rows     :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  sidekiq_job_id :string
#  user_id        :bigint           not null
#
# Indexes
#
#  idx_import_batches_version       (user_id,import_type,import_version) UNIQUE
#  index_import_batches_on_user_id  (user_id)
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
                       completed: "completed", failed: "failed" }, validate: true

  validates :import_type, :status, :file_name, presence: true

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
