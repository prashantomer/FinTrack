class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string  :import_type,    null: false
      t.string  :status,         null: false, default: "pending"
      t.string  :file_name,      null: false
      t.text    :raw_csv,        null: false
      t.integer :total_rows,     null: false, default: 0
      t.integer :processed_rows, null: false, default: 0
      t.integer :failed_rows,    null: false, default: 0
      t.integer :import_version, null: false, default: 1
      t.string  :sidekiq_job_id

      t.timestamps
    end

    add_index :import_batches, [:user_id, :import_type, :import_version],
              unique: true, name: "idx_import_batches_version"
  end
end
