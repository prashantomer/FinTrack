# == Schema Information
#
# Table name: accounts
#
#  id             :bigint           not null, primary key
#  account_number :string(50)
#  account_type   :string           default("savings"), not null
#  balance        :decimal(14, 2)   default(0.0), not null
#  closed_amount  :decimal(14, 2)
#  closed_date    :date
#  nickname       :string(100)      not null
#  open_date      :date             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  bank_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_accounts_on_bank_id  (bank_id)
#  index_accounts_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (bank_id => banks.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Account < ApplicationRecord
  class Error < StandardError; end

  audited only: [ :balance ]

  has_many :imports, class_name: "ImportBatch", as: :linked_account
  has_many :transactions, as: :linked_account

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

  validates :nickname,  presence: true
  # `open_date` is the immutable cutoff: anything before it is folded into
  # the user-supplied opening transaction (a regular credit dated on that
  # day). The DB column is NOT NULL so this presence validation is belt
  # + braces.
  validates :open_date, presence: true

  def closed?
    closed_date.present?
  end

  # Direct credit/debit (not driven by a Transaction). Callers MUST pass
  # `source:` so the audit row records what caused the change — e.g.
  # `account.credit!(amount, source: "close:term_account_#{ta.id}")`.
  # Without a source the audit log shows an anonymous "Balance update",
  # which is what we used to do — and which made past mysteries hard to
  # trace back to their cause.
  def debit!(amount, source: nil)
    raise Error, "Account '#{nickname}' is closed" if closed?
    raise Error, "Insufficient balance in '#{nickname}' (available: #{balance}, required: #{amount})" if balance < amount
    self.audit_comment = source if source
    update!(balance: balance - amount)
  end

  def credit!(amount, source: nil)
    raise Error, "Account '#{nickname}' is closed" if closed?
    self.audit_comment = source if source
    update!(balance: balance + amount)
  end
end
