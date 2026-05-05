class Investment < ApplicationRecord
  belongs_to :user
  belongs_to :platform_account, optional: true
  belongs_to :user_instrument,  optional: true
  has_one    :import_record, as: :importable, dependent: :nullify

  enum :investment_type, { stock: "stock", mutual_fund: "mutual_fund" }, validate: true

  validates :name,            presence: true
  validates :amount_invested, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_date,   presence: true
end
