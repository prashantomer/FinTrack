class AddLongShortTermUnitsToHoldings < ActiveRecord::Migration[8.1]
  def change
    add_column :holdings, :long_term_units, :decimal, precision: 15, scale: 4
    add_column :holdings, :short_term_units, :decimal, precision: 15, scale: 4
  end
end
