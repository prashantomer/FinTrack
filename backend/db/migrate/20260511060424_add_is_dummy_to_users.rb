class AddIsDummyToUsers < ActiveRecord::Migration[8.1]
  def change
    # Marks users as demo / seed / test data so they can be filtered out of
    # real-user counts and admin reports. Real users are the default.
    add_column :users, :is_dummy, :boolean, default: false, null: false
    add_index  :users, :is_dummy
  end
end
