class AddImportNumberToImportBatches < ActiveRecord::Migration[8.1]
  def up
    # Friendly per-user identifier shown in the UI ("Import #42"). Unlike
    # `import_version` (which is per-type, so investments and transactions
    # both have their own v1/v2/...), `import_number` is global within a
    # user — every batch is a distinct sequence number regardless of type.
    add_column :import_batches, :import_number, :integer

    # Backfill existing rows per user, ordered by creation time.
    execute <<~SQL
      WITH numbered AS (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at, id) AS n
        FROM import_batches
      )
      UPDATE import_batches
      SET import_number = numbered.n
      FROM numbered
      WHERE import_batches.id = numbered.id
    SQL

    change_column_null :import_batches, :import_number, false
    add_index :import_batches, [ :user_id, :import_number ], unique: true,
              name: "idx_import_batches_user_id_import_number"
  end

  def down
    remove_index  :import_batches, name: "idx_import_batches_user_id_import_number"
    remove_column :import_batches, :import_number
  end
end
