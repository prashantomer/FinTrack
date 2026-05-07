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
class ImportBatchSerializer < BaseSerializer
  def self.attributes(r)
    {
      id:             r.id,
      import_type:    r.import_type,
      status:         r.status,
      file_name:      r.file_name,
      total_rows:     r.total_rows,
      processed_rows: r.processed_rows,
      failed_rows:    r.failed_rows,
      duplicate_rows: r.duplicate_rows,
      import_version: r.import_version,
      progress_pct:   r.progress_pct,
      import_records: r.association(:import_records).loaded? ? import_records_data(r) : [],
      created_at:     r.created_at
    }
  end

  def self.import_records_data(r)
    r.import_records.map do |ir|
      { row_index: ir.row_index, status: ir.status, notes: ir.notes }
    end
  end
  private_class_method :import_records_data
end
