class CreateInstruments < ActiveRecord::Migration[8.1]
  def change
    create_table :instruments do |t|
      t.string :name,            null: false, limit: 255
      t.string :investment_type, null: false
      t.string :ticker_symbol,   limit: 20
      t.string :isin,            limit: 20
      t.string :exchange,        limit: 20
      t.string :fund_house,      limit: 100
      t.timestamps
    end
    add_index :instruments, :name
    add_index :instruments, :investment_type
  end
end
