class AddLastPriceToInstruments < ActiveRecord::Migration[8.1]
  def change
    add_column :instruments, :last_price, :decimal, precision: 15, scale: 4
    add_column :instruments, :last_price_at, :datetime
  end
end
