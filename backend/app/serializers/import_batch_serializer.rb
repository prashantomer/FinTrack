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
