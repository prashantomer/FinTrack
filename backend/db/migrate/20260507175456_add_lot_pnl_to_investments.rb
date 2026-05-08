class AddLotPnlToInvestments < ActiveRecord::Migration[8.1]
  def change
    add_column :investments, :lot_realized_gain, :decimal, precision: 14, scale: 2
    add_column :investments, :lot_unrealized_gain, :decimal, precision: 14, scale: 2
    add_column :investments, :lot_pnl_at, :datetime
  end
end
