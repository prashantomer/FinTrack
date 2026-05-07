class UnifyInvestmentPrice < ActiveRecord::Migration[8.1]
  def change
    add_column :investments, :price, :decimal, precision: 14, scale: 4

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE investments
          SET price = COALESCE(buy_price, nav_at_purchase)
        SQL
      end
    end

    remove_column :investments, :buy_price,       :decimal, precision: 12, scale: 2
    remove_column :investments, :nav_at_purchase, :decimal, precision: 12, scale: 4
  end
end
