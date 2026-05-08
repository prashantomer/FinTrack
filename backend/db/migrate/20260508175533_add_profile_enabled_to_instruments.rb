class AddProfileEnabledToInstruments < ActiveRecord::Migration[8.1]
  def change
    add_column :instruments, :profile_enabled, :boolean, default: false, null: false
  end
end
