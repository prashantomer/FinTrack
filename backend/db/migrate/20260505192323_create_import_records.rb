class CreateImportRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :import_records do |t|
      t.references :import_batch, null: false, foreign_key: { on_delete: :cascade }
      t.string  :importable_type
      t.bigint  :importable_id
      t.integer :row_index,      null: false
      t.string  :status,         null: false, default: "ok"
      t.text    :notes

      t.datetime :created_at, null: false
    end

    add_index :import_records, [ :importable_type, :importable_id ], name: "idx_import_records_importable"
  end
end
