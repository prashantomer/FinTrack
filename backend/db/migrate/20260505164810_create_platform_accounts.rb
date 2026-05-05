class CreatePlatformAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_accounts do |t|
      t.references :user,     null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :platform, null: false, foreign_key: { on_delete: :restrict }
      t.string :nickname,   null: false, limit: 100
      t.string :account_id, limit: 50
      t.timestamps
    end
  end
end
