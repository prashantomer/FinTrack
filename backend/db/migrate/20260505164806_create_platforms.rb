class CreatePlatforms < ActiveRecord::Migration[8.1]
  def change
    create_table :platforms do |t|
      t.string  :name,          null: false, limit: 100
      t.string  :short_name,    null: false, limit: 20
      t.string  :platform_type, null: false
      t.boolean :is_system,     null: false, default: false
      t.timestamps
    end
    add_index :platforms, :short_name, unique: true
  end
end
