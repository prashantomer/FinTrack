class AddSourceToInvestmentsAndTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :investments,  :source, :string, default: "manual", null: false
    add_column :transactions, :source, :string, default: "manual", null: false

    # Backfill from import_records (polymorphic importable_type/id). Anything
    # the importer ever wrote stays read-only post-migration; everything else
    # is treated as a manual entry the user typed in.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE investments SET source = 'imported'
          WHERE id IN (
            SELECT importable_id FROM import_records
            WHERE importable_type = 'Investment' AND importable_id IS NOT NULL
          )
        SQL
        execute <<~SQL
          UPDATE transactions SET source = 'imported'
          WHERE id IN (
            SELECT importable_id FROM import_records
            WHERE importable_type = 'Transaction' AND importable_id IS NOT NULL
          )
        SQL
      end
    end
  end
end
