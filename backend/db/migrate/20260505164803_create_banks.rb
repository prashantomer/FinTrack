class CreateBanks < ActiveRecord::Migration[8.1]
  def change
    create_table :banks do |t|
      t.string  :name,       null: false, limit: 100
      t.string  :short_name, null: false, limit: 6
      t.boolean :is_system,  null: false, default: false
      t.timestamps
    end
    add_index :banks, :short_name, unique: true
  end
end
