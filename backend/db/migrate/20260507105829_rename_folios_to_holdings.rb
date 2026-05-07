class RenameFoliosToHoldings < ActiveRecord::Migration[8.1]
  def up
    rename_table :folios, :holdings
    rename_index :holdings, "uq_folio_user_instrument_account", "uq_holding_user_instrument_account"

    # STI discriminator. Existing rows are mutual-fund Folios.
    add_column :holdings, :type, :string, null: false, default: "Folio"
    add_index  :holdings, :type

    # Stat-cache columns — populated by Holdings::RefreshService instead of
    # being computed on every report request.
    add_column :holdings, :buy_lots,           :integer
    add_column :holdings, :sell_lots,          :integer
    add_column :holdings, :total_units,        :decimal, precision: 15, scale: 4
    add_column :holdings, :avg_buy_price,      :decimal, precision: 14, scale: 4
    add_column :holdings, :total_invested,     :decimal, precision: 14, scale: 2
    add_column :holdings, :current_value,      :decimal, precision: 14, scale: 2
    add_column :holdings, :unrealized_gain,    :decimal, precision: 14, scale: 2
    add_column :holdings, :realized_gain,      :decimal, precision: 14, scale: 2
    add_column :holdings, :is_closed,          :boolean, default: false, null: false
    add_column :holdings, :last_calculated_at, :datetime
  end

  def down
    %i[last_calculated_at is_closed realized_gain unrealized_gain current_value
       total_invested avg_buy_price total_units sell_lots buy_lots type].each do |col|
      remove_column :holdings, col
    end
    rename_index :holdings, "uq_holding_user_instrument_account", "uq_folio_user_instrument_account"
    rename_table :holdings, :folios
  end
end
