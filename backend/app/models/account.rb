class Account < ApplicationRecord
  class Error < StandardError; end

  audited only: [:balance]

  belongs_to :user
  belongs_to :bank

  enum :account_type, {
    savings: "savings",
    current: "current",
    salary:  "salary",
    nre:     "nre",
    nro:     "nro"
  }, validate: true

  scope :open,   -> { where(closed_date: nil) }
  scope :closed, -> { where.not(closed_date: nil) }

  validates :nickname, presence: true

  def closed?
    closed_date.present?
  end

  def debit!(amount)
    raise Error, "Account '#{nickname}' is closed" if closed?
    raise Error, "Insufficient balance in '#{nickname}' (available: #{balance}, required: #{amount})" if balance < amount
    update!(balance: balance - amount)
  end

  def credit!(amount)
    raise Error, "Account '#{nickname}' is closed" if closed?
    update!(balance: balance + amount)
  end
end
