class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      # polymorphic linked account — manual (no Rails polymorphic macro)
      t.string  :linked_account_type, index: true
      t.integer :linked_account_id,   index: true
      t.references :instrument, foreign_key: { on_delete: :nullify }
      t.decimal :amount,            null: false, precision: 12, scale: 2
      t.string  :transaction_type,  null: false
      t.string  :tags,              array: true
      t.string  :description,       limit: 500
      t.string  :bank_ref,          limit: 100
      t.date    :date,              null: false
      t.uuid    :public_id,         default: -> { "gen_random_uuid()" }
      t.boolean :is_active,         null: false, default: true
      t.timestamps
    end
    add_index :transactions, [:date, :id]
    add_index :transactions, :public_id, unique: true
  end
end
