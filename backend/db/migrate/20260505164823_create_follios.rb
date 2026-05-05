class CreateFollios < ActiveRecord::Migration[8.1]
  def change
    create_table :follios do |t|
      t.references :user_instrument, null: false, foreign_key: { on_delete: :cascade }
      t.string :folio_number, null: false, limit: 50
      t.text   :notes
      t.timestamps
    end
  end
end
