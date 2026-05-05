class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :email,           null: false
      t.string  :first_name,      null: false
      t.string  :last_name,       null: false
      t.string  :password_digest, null: false
      t.boolean :is_active,       null: false, default: true
      t.boolean :is_superuser,    null: false, default: false
      t.string  :currency_code,   null: false, default: "INR"
      t.string  :currency_locale, null: false, default: "en-IN"
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
