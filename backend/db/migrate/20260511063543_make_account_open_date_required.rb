class MakeAccountOpenDateRequired < ActiveRecord::Migration[8.1]
  def up
    # Defensive backfill — all rows already have a value, but this protects
    # against re-running the migration on environments that pre-date open_date
    # being a required form field.
    execute "UPDATE accounts SET open_date = COALESCE(open_date, created_at::date)"
    change_column_null :accounts, :open_date, false
  end

  def down
    change_column_null :accounts, :open_date, true
  end
end
