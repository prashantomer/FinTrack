class Instrument < ApplicationRecord
  has_many :user_instruments, dependent: :destroy
  has_many :users,            through: :user_instruments

  enum :investment_type, { stock: "stock", mutual_fund: "mutual_fund" }, validate: true

  scope :alphabetical, -> { order(:name, :ticker_symbol) }

  validates :name, presence: true
end
