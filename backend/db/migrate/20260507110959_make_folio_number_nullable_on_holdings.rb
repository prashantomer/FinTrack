class MakeFolioNumberNullableOnHoldings < ActiveRecord::Migration[8.1]
  def up
    change_column_null :holdings, :folio_number, true
  end

  def down
    # Backfill any nulls before re-applying NOT NULL.
    execute "UPDATE holdings SET folio_number = '(unset)' WHERE folio_number IS NULL"
    change_column_null :holdings, :folio_number, false
  end
end
