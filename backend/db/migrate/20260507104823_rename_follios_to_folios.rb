class RenameFolliosToFolios < ActiveRecord::Migration[8.1]
  def up
    rename_table :follios, :folios

    # Rename indexes (Rails auto-renames index names that include the old table
    # name, but only for the standard ones — explicit ones must be renamed.)
    rename_index :folios, "uq_follio_user_instrument_account", "uq_folio_user_instrument_account"
  end

  def down
    rename_index :folios, "uq_folio_user_instrument_account", "uq_follio_user_instrument_account"
    rename_table :folios, :follios
  end
end
