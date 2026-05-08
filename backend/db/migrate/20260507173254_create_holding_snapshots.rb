class CreateHoldingSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :holding_snapshots do |t|
      t.references :user,                null: false, foreign_key: { on_delete: :cascade }
      t.references :holding,             null: false, foreign_key: { on_delete: :cascade }
      t.references :platform_account,    null: false, foreign_key: { on_delete: :cascade }
      t.references :user_instrument,     null: false, foreign_key: { on_delete: :cascade }
      t.date       :snapshot_date,       null: false

      t.decimal :market_price,    precision: 14, scale: 4
      t.decimal :total_units,     precision: 15, scale: 4
      t.decimal :avg_buy_price,   precision: 14, scale: 4
      t.decimal :total_invested,  precision: 14, scale: 2
      t.decimal :current_value,   precision: 14, scale: 2
      t.decimal :unrealized_gain, precision: 14, scale: 2
      t.decimal :realized_gain,   precision: 14, scale: 2
      t.boolean :is_closed,       null: false, default: false

      t.datetime :created_at, null: false
    end

    add_index :holding_snapshots, [ :holding_id, :snapshot_date ],
              unique: true, name: "uq_holding_snapshot_per_day"
    add_index :holding_snapshots, [ :user_id, :snapshot_date ]
    add_index :holding_snapshots, [ :platform_account_id, :snapshot_date ]
  end
end
