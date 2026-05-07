class AddOrderIdToInvestments < ActiveRecord::Migration[8.1]
  def change
    add_column :investments, :order_id, :string, limit: 64
    add_index  :investments, :order_id
  end
end
