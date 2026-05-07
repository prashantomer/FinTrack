class AddUpdatedAtToSnapshotTables < ActiveRecord::Migration[8.1]
  def up
    add_column :instrument_price_history, :updated_at, :datetime
    execute "UPDATE instrument_price_history SET updated_at = created_at WHERE updated_at IS NULL"
    change_column_null :instrument_price_history, :updated_at, false

    add_column :holding_snapshots, :updated_at, :datetime
    execute "UPDATE holding_snapshots SET updated_at = created_at WHERE updated_at IS NULL"
    change_column_null :holding_snapshots, :updated_at, false
  end

  def down
    remove_column :instrument_price_history, :updated_at
    remove_column :holding_snapshots,        :updated_at
  end
end
