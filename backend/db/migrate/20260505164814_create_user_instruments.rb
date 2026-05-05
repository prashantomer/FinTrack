class CreateUserInstruments < ActiveRecord::Migration[8.1]
  def change
    create_table :user_instruments do |t|
      t.references :user,       null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :instrument, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :added_at, null: false, default: -> { "NOW()" }
    end
    add_index :user_instruments, [:user_id, :instrument_id], unique: true
  end
end
