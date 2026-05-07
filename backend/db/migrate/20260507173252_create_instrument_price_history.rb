class CreateInstrumentPriceHistory < ActiveRecord::Migration[8.1]
  def change
    create_table :instrument_price_history do |t|
      t.references :instrument, null: false, foreign_key: { on_delete: :cascade }
      t.date       :price_date, null: false
      t.decimal    :price,      precision: 14, scale: 4, null: false
      t.string     :source,     limit: 16
      t.datetime   :created_at, null: false
    end

    add_index :instrument_price_history, [ :instrument_id, :price_date ],
              unique: true, name: "uq_instr_price_history_per_day"
  end
end
