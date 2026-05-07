class AddDuplicateRowsToImportBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :import_batches, :duplicate_rows, :integer, default: 0, null: false
  end
end
