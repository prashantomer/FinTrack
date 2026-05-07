# == Schema Information
#
# Table name: instrument_price_history
#
#  id            :bigint           not null, primary key
#  price         :decimal(14, 4)   not null
#  price_date    :date             not null
#  source        :string(16)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  instrument_id :bigint           not null
#
# Indexes
#
#  index_instrument_price_history_on_instrument_id  (instrument_id)
#  uq_instr_price_history_per_day                   (instrument_id,price_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (instrument_id => instruments.id) ON DELETE => cascade
#
class InstrumentPriceHistory < ApplicationRecord
  self.table_name = "instrument_price_history"

  belongs_to :instrument

  validates :price_date, :price, presence: true
  validates :instrument_id, uniqueness: { scope: :price_date }

  scope :for_instrument, ->(id) { where(instrument_id: id) }
  scope :on_or_before,   ->(d)  { where("price_date <= ?", d) }
  scope :latest_first,   ->     { order(price_date: :desc) }
end
