class CreateInvestments < ActiveRecord::Migration[8.1]
  def change
    create_table :investments do |t|
      t.references :user,             null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :platform_account, foreign_key: { on_delete: :nullify }
      t.references :user_instrument,  foreign_key: { on_delete: :nullify }
      t.string  :investment_type,   null: false
      t.string  :name,              null: false, limit: 255
      t.decimal :amount_invested,   null: false, precision: 14, scale: 2
      t.decimal :current_value,     precision: 14, scale: 2
      t.date    :purchase_date,     null: false
      t.text    :notes
      # stock / ETF
      t.decimal :quantity,          precision: 12, scale: 4
      t.decimal :buy_price,         precision: 12, scale: 2
      # mutual fund
      t.string  :folio_number,      limit: 50
      t.decimal :units,             precision: 12, scale: 4
      t.decimal :nav_at_purchase,   precision: 12, scale: 4
      # traceability (soft ref to transactions.public_id — no FK)
      t.uuid    :transaction_public_id
      t.timestamps
    end
    add_index :investments, :investment_type
    add_index :investments, :transaction_public_id
  end
end
