class AddTradeIdToInvestments < ActiveRecord::Migration[8.1]
  def change
    add_column :investments, :trade_id, :string, limit: 64
    add_index  :investments, :trade_id
    add_index  :investments, [ :order_id, :trade_id ]
  end
end
