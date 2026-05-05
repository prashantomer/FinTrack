class CreateTermAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :term_accounts do |t|
      t.references :user,           null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :parent_account, null: false, foreign_key: { to_table: :accounts, on_delete: :restrict }
      t.string  :account_type,   null: false
      t.string  :account_number, limit: 100
      t.decimal :amount,         null: false, precision: 14, scale: 2
      t.date    :open_date,      null: false
      t.integer :tenure_days
      t.decimal :interest_rate,  null: false, precision: 5, scale: 2
      t.date    :maturity_date,  null: false
      t.decimal :maturity_amount, null: false, precision: 14, scale: 2
      t.decimal :balance,        null: false, precision: 14, scale: 2, default: 0
      t.date    :closed_date
      t.decimal :closed_amount,  precision: 14, scale: 2
      t.boolean :is_active,      null: false, default: true
      t.text    :notes
      t.timestamps
    end
  end
end
