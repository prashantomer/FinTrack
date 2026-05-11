class AddReconciliationFieldsToImportBatches < ActiveRecord::Migration[8.1]
  def change
    # User's choice for what to do when the source file's running balance
    # (e.g., ICICI's Balance(INR) column) disagrees with the post-import
    # account.balance. "fail" rolls the batch back; "adjust" creates a
    # balancing adjustment transaction. "ask" surfaces the choice via the
    # UI after the import finishes and waits for the user to resolve it.
    add_column :import_batches, :on_balance_mismatch, :string, default: "ask", null: false
    # Last running balance pulled from the source file (xls Balance(INR)
    # column). Compared against account.balance at end of import.
    add_column :import_batches, :expected_balance, :decimal, precision: 14, scale: 2
  end
end
