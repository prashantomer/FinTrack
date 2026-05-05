class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :bank, null: false, foreign_key: { on_delete: :restrict }
      t.string  :nickname,       null: false, limit: 100
      t.string  :account_number, limit: 50
      t.string  :account_type,   null: false, default: "savings"
      t.decimal :balance,        null: false, precision: 14, scale: 2, default: 0
      t.date    :open_date
      t.date    :closed_date
      t.decimal :closed_amount,  precision: 14, scale: 2
      t.timestamps
    end
  end
end
