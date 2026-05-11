# == Schema Information
#
# Table name: instruments
#
#  id              :bigint           not null, primary key
#  exchange        :string(20)
#  fund_house      :string(100)
#  investment_type :string           not null
#  isin            :string(20)
#  last_price      :decimal(15, 4)
#  last_price_at   :datetime
#  name            :string(255)      not null
#  profile_enabled :boolean          default(FALSE), not null
#  ticker_symbol   :string(20)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_instruments_on_investment_type  (investment_type)
#  index_instruments_on_name             (name)
#
class Instrument < ApplicationRecord
  has_many :user_instruments, dependent: :destroy
  has_many :users,            through: :user_instruments

  enum :investment_type, { stock: "stock", mutual_fund: "mutual_fund" }, validate: true

  scope :alphabetical, -> { order(:name, :ticker_symbol) }

  validates :name, presence: true
end
