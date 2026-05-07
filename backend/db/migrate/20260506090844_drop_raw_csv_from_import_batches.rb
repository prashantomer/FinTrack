class DropRawCsvFromImportBatches < ActiveRecord::Migration[8.1]
  def change
    remove_column :import_batches, :raw_csv, :text
  end
end
