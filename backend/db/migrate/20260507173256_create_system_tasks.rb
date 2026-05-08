class CreateSystemTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :system_tasks do |t|
      t.string   :name,                 null: false
      t.date     :last_completed_date
      t.datetime :last_completed_at
      t.string   :last_status, limit: 16
      t.text     :last_error
      t.timestamps
    end

    add_index :system_tasks, :name, unique: true
  end
end
