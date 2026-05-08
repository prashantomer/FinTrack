# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_07_175456) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "accounts", force: :cascade do |t|
    t.string "account_number", limit: 50
    t.string "account_type", default: "savings", null: false
    t.decimal "balance", precision: 14, scale: 2, default: "0.0", null: false
    t.bigint "bank_id", null: false
    t.decimal "closed_amount", precision: 14, scale: 2
    t.date "closed_date"
    t.datetime "created_at", null: false
    t.string "nickname", limit: 100, null: false
    t.date "open_date"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bank_id"], name: "index_accounts_on_bank_id"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assistant_messages", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "latency_ms"
    t.string "model"
    t.boolean "pinned", default: false, null: false
    t.string "provider"
    t.string "role", null: false
    t.uuid "session_id", null: false
    t.integer "token_estimate"
    t.integer "tokens_in"
    t.integer "tokens_out"
    t.jsonb "tool_arguments"
    t.string "tool_name"
    t.jsonb "tool_result"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_assistant_messages_on_user_id_and_created_at"
    t.index ["user_id", "session_id"], name: "index_assistant_messages_on_user_id_and_session_id"
    t.index ["user_id"], name: "idx_assistant_messages_pinned", where: "(pinned IS TRUE)"
    t.index ["user_id"], name: "index_assistant_messages_on_user_id"
  end

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "banks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_system", default: false, null: false
    t.string "name", limit: 100, null: false
    t.string "short_name", limit: 6, null: false
    t.datetime "updated_at", null: false
    t.index ["short_name"], name: "index_banks_on_short_name", unique: true
  end

  create_table "holding_snapshots", force: :cascade do |t|
    t.decimal "avg_buy_price", precision: 14, scale: 4
    t.datetime "created_at", null: false
    t.decimal "current_value", precision: 14, scale: 2
    t.bigint "holding_id", null: false
    t.boolean "is_closed", default: false, null: false
    t.decimal "market_price", precision: 14, scale: 4
    t.bigint "platform_account_id", null: false
    t.decimal "realized_gain", precision: 14, scale: 2
    t.date "snapshot_date", null: false
    t.decimal "total_invested", precision: 14, scale: 2
    t.decimal "total_units", precision: 15, scale: 4
    t.decimal "unrealized_gain", precision: 14, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_instrument_id", null: false
    t.index ["holding_id", "snapshot_date"], name: "uq_holding_snapshot_per_day", unique: true
    t.index ["holding_id"], name: "index_holding_snapshots_on_holding_id"
    t.index ["platform_account_id", "snapshot_date"], name: "idx_on_platform_account_id_snapshot_date_145f899a61"
    t.index ["platform_account_id"], name: "index_holding_snapshots_on_platform_account_id"
    t.index ["user_id", "snapshot_date"], name: "index_holding_snapshots_on_user_id_and_snapshot_date"
    t.index ["user_id"], name: "index_holding_snapshots_on_user_id"
    t.index ["user_instrument_id"], name: "index_holding_snapshots_on_user_instrument_id"
  end

  create_table "holdings", force: :cascade do |t|
    t.decimal "avg_buy_price", precision: 14, scale: 4
    t.integer "buy_lots"
    t.datetime "created_at", null: false
    t.decimal "current_value", precision: 14, scale: 2
    t.string "folio_number", limit: 50
    t.boolean "is_closed", default: false, null: false
    t.datetime "last_calculated_at"
    t.decimal "long_term_units", precision: 15, scale: 4
    t.text "notes"
    t.bigint "platform_account_id", null: false
    t.decimal "realized_gain", precision: 14, scale: 2
    t.integer "sell_lots"
    t.decimal "short_term_units", precision: 15, scale: 4
    t.decimal "total_invested", precision: 14, scale: 2
    t.decimal "total_units", precision: 15, scale: 4
    t.string "type", default: "Folio", null: false
    t.decimal "unrealized_gain", precision: 14, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_instrument_id", null: false
    t.index ["platform_account_id"], name: "index_holdings_on_platform_account_id"
    t.index ["type"], name: "index_holdings_on_type"
    t.index ["user_id"], name: "index_holdings_on_user_id"
    t.index ["user_instrument_id", "platform_account_id"], name: "uq_holding_user_instrument_account", unique: true
    t.index ["user_instrument_id"], name: "index_holdings_on_user_instrument_id"
  end

  create_table "import_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duplicate_rows", default: 0, null: false
    t.integer "failed_rows", default: 0, null: false
    t.string "file_name", null: false
    t.string "import_type", null: false
    t.integer "import_version", default: 1, null: false
    t.integer "processed_rows", default: 0, null: false
    t.string "sidekiq_job_id"
    t.string "status", default: "pending", null: false
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "import_type", "import_version"], name: "idx_import_batches_version", unique: true
    t.index ["user_id"], name: "index_import_batches_on_user_id"
  end

  create_table "import_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "import_batch_id", null: false
    t.bigint "importable_id"
    t.string "importable_type"
    t.text "notes"
    t.integer "row_index", null: false
    t.string "status", default: "ok", null: false
    t.index ["import_batch_id"], name: "index_import_records_on_import_batch_id"
    t.index ["importable_type", "importable_id"], name: "idx_import_records_importable"
  end

  create_table "instrument_price_history", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "instrument_id", null: false
    t.decimal "price", precision: 14, scale: 4, null: false
    t.date "price_date", null: false
    t.string "source", limit: 16
    t.datetime "updated_at", null: false
    t.index ["instrument_id", "price_date"], name: "uq_instr_price_history_per_day", unique: true
    t.index ["instrument_id"], name: "index_instrument_price_history_on_instrument_id"
  end

  create_table "instruments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "exchange", limit: 20
    t.string "fund_house", limit: 100
    t.string "investment_type", null: false
    t.string "isin", limit: 20
    t.decimal "last_price", precision: 15, scale: 4
    t.datetime "last_price_at"
    t.string "name", limit: 255, null: false
    t.string "ticker_symbol", limit: 20
    t.datetime "updated_at", null: false
    t.index ["investment_type"], name: "index_instruments_on_investment_type"
    t.index ["name"], name: "index_instruments_on_name"
  end

  create_table "investments", force: :cascade do |t|
    t.decimal "amount_invested", precision: 14, scale: 2, null: false
    t.datetime "created_at", null: false
    t.decimal "current_value", precision: 14, scale: 2
    t.string "folio_number", limit: 50
    t.string "investment_type", null: false
    t.datetime "lot_pnl_at"
    t.decimal "lot_realized_gain", precision: 14, scale: 2
    t.decimal "lot_unrealized_gain", precision: 14, scale: 2
    t.string "name", limit: 255, null: false
    t.text "notes"
    t.string "order_id", limit: 64
    t.bigint "platform_account_id"
    t.decimal "price", precision: 14, scale: 4
    t.date "purchase_date", null: false
    t.decimal "quantity", precision: 12, scale: 4
    t.string "trade_id", limit: 64
    t.string "trade_type", default: "buy", null: false
    t.uuid "transaction_public_id"
    t.decimal "units", precision: 12, scale: 4
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_instrument_id"
    t.index ["investment_type"], name: "index_investments_on_investment_type"
    t.index ["order_id", "trade_id"], name: "index_investments_on_order_id_and_trade_id"
    t.index ["order_id"], name: "index_investments_on_order_id"
    t.index ["platform_account_id"], name: "index_investments_on_platform_account_id"
    t.index ["trade_id"], name: "index_investments_on_trade_id"
    t.index ["trade_type"], name: "index_investments_on_trade_type"
    t.index ["transaction_public_id"], name: "index_investments_on_transaction_public_id"
    t.index ["user_id"], name: "index_investments_on_user_id"
    t.index ["user_instrument_id"], name: "index_investments_on_user_instrument_id"
  end

  create_table "platform_accounts", force: :cascade do |t|
    t.string "account_id", limit: 50
    t.datetime "created_at", null: false
    t.string "nickname", limit: 100, null: false
    t.bigint "platform_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["platform_id"], name: "index_platform_accounts_on_platform_id"
    t.index ["user_id"], name: "index_platform_accounts_on_user_id"
  end

  create_table "platforms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_system", default: false, null: false
    t.string "name", limit: 100, null: false
    t.string "platform_type", null: false
    t.string "short_name", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.index ["short_name"], name: "index_platforms_on_short_name", unique: true
  end

  create_table "system_tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_completed_at"
    t.date "last_completed_date"
    t.text "last_error"
    t.string "last_status", limit: 16
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_system_tasks_on_name", unique: true
  end

  create_table "term_accounts", force: :cascade do |t|
    t.string "account_number", limit: 100
    t.string "account_type", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.decimal "balance", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "closed_amount", precision: 14, scale: 2
    t.date "closed_date"
    t.datetime "created_at", null: false
    t.decimal "interest_rate", precision: 5, scale: 2, null: false
    t.boolean "is_active", default: true, null: false
    t.decimal "maturity_amount", precision: 14, scale: 2, null: false
    t.date "maturity_date", null: false
    t.text "notes"
    t.date "open_date", null: false
    t.bigint "parent_account_id", null: false
    t.integer "tenure_days"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["parent_account_id"], name: "index_term_accounts_on_parent_account_id"
    t.index ["user_id"], name: "index_term_accounts_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "bank_ref", limit: 100
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description", limit: 500
    t.bigint "instrument_id"
    t.boolean "is_active", default: true, null: false
    t.integer "linked_account_id"
    t.string "linked_account_type"
    t.uuid "public_id", default: -> { "gen_random_uuid()" }
    t.string "tags", array: true
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["date", "id"], name: "index_transactions_on_date_and_id"
    t.index ["instrument_id"], name: "index_transactions_on_instrument_id"
    t.index ["linked_account_id"], name: "index_transactions_on_linked_account_id"
    t.index ["linked_account_type"], name: "index_transactions_on_linked_account_type"
    t.index ["public_id"], name: "index_transactions_on_public_id", unique: true
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "user_assistant_settings", force: :cascade do |t|
    t.text "api_key"
    t.string "base_url"
    t.datetime "created_at", null: false
    t.integer "daily_limit", default: 100, null: false
    t.text "last_test_error"
    t.string "last_test_status"
    t.datetime "last_tested_at"
    t.string "model"
    t.string "provider"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_assistant_settings_on_user_id", unique: true
  end

  create_table "user_instruments", force: :cascade do |t|
    t.datetime "added_at", default: -> { "now()" }, null: false
    t.bigint "instrument_id", null: false
    t.bigint "user_id", null: false
    t.index ["instrument_id"], name: "index_user_instruments_on_instrument_id"
    t.index ["user_id", "instrument_id"], name: "index_user_instruments_on_user_id_and_instrument_id", unique: true
    t.index ["user_id"], name: "index_user_instruments_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", default: "INR", null: false
    t.string "currency_locale", default: "en-IN", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_superuser", default: false, null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "accounts", "banks", on_delete: :restrict
  add_foreign_key "accounts", "users", on_delete: :cascade
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assistant_messages", "users"
  add_foreign_key "holding_snapshots", "holdings", on_delete: :cascade
  add_foreign_key "holding_snapshots", "platform_accounts", on_delete: :cascade
  add_foreign_key "holding_snapshots", "user_instruments", on_delete: :cascade
  add_foreign_key "holding_snapshots", "users", on_delete: :cascade
  add_foreign_key "holdings", "platform_accounts", on_delete: :cascade
  add_foreign_key "holdings", "user_instruments", on_delete: :cascade
  add_foreign_key "holdings", "users", on_delete: :cascade
  add_foreign_key "import_batches", "users", on_delete: :cascade
  add_foreign_key "import_records", "import_batches", on_delete: :cascade
  add_foreign_key "instrument_price_history", "instruments", on_delete: :cascade
  add_foreign_key "investments", "platform_accounts", on_delete: :nullify
  add_foreign_key "investments", "user_instruments", on_delete: :nullify
  add_foreign_key "investments", "users", on_delete: :cascade
  add_foreign_key "platform_accounts", "platforms", on_delete: :restrict
  add_foreign_key "platform_accounts", "users", on_delete: :cascade
  add_foreign_key "term_accounts", "accounts", column: "parent_account_id", on_delete: :restrict
  add_foreign_key "term_accounts", "users", on_delete: :cascade
  add_foreign_key "transactions", "instruments", on_delete: :nullify
  add_foreign_key "transactions", "users", on_delete: :cascade
  add_foreign_key "user_assistant_settings", "users"
  add_foreign_key "user_instruments", "instruments", on_delete: :cascade
  add_foreign_key "user_instruments", "users", on_delete: :cascade
end
