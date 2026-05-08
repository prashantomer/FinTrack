class CreateAssistantTables < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :user_assistant_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string  :provider                       # nil = unconfigured → fallback to ollama
      t.string  :model
      t.text    :api_key                        # encrypted via `encrypts :api_key`
      t.string  :base_url
      t.integer :daily_limit, null: false, default: 100
      t.datetime :last_tested_at
      t.string  :last_test_status               # ok | error
      t.text    :last_test_error
      t.timestamps
    end

    create_table :assistant_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.uuid    :session_id, null: false
      t.string  :role, null: false              # user | assistant | tool
      t.text    :content
      t.string  :tool_name
      t.jsonb   :tool_arguments
      t.jsonb   :tool_result
      t.boolean :pinned, null: false, default: false
      t.integer :token_estimate
      # Telemetry, populated only on role=assistant rows
      t.string  :provider
      t.string  :model
      t.integer :tokens_in
      t.integer :tokens_out
      t.integer :latency_ms
      t.timestamps
    end

    add_index :assistant_messages, [ :user_id, :created_at ]
    add_index :assistant_messages, [ :user_id, :session_id ]
    add_index :assistant_messages, :user_id, name: "idx_assistant_messages_pinned",
              where: "pinned IS TRUE"
  end
end
