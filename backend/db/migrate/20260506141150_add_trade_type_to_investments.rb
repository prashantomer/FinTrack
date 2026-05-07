class AddTradeTypeToInvestments < ActiveRecord::Migration[8.1]
  def change
    add_column :investments, :trade_type, :string, null: false, default: "buy"
    add_index  :investments, :trade_type
  end
end
