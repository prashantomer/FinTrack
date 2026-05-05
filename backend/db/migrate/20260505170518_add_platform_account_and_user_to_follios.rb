class AddPlatformAccountAndUserToFollios < ActiveRecord::Migration[8.1]
  def change
    add_reference :follios, :platform_account, null: false, foreign_key: { on_delete: :cascade }
    add_reference :follios, :user, null: false, foreign_key: { on_delete: :cascade }
    add_index :follios, [ :user_instrument_id, :platform_account_id ], unique: true, name: "uq_follio_user_instrument_account"
  end
end
