class AddResultMessageToImportBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :import_batches, :result_message, :text
  end
end
