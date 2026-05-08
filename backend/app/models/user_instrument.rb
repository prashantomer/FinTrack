# == Schema Information
#
# Table name: user_instruments
#
#  id            :bigint           not null, primary key
#  added_at      :datetime         not null
#  instrument_id :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_instruments_on_instrument_id              (instrument_id)
#  index_user_instruments_on_user_id                    (user_id)
#  index_user_instruments_on_user_id_and_instrument_id  (user_id,instrument_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (instrument_id => instruments.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class UserInstrument < ApplicationRecord
  belongs_to :user
  belongs_to :instrument

  has_many :holdings,        dependent: :destroy
  has_many :folios,          -> { where(type: "Folio") },         class_name: "Folio"
  has_many :equity_holdings, -> { where(type: "EquityHolding") }, class_name: "EquityHolding"
  has_many :investments,     dependent: :nullify

  validates :user_id, uniqueness: { scope: :instrument_id }
end
