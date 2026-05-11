class AddLinkedAccountToImportBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :import_batches, :linked_account_type, :string
    add_column :import_batches, :linked_account_id, :bigint
  end
end
