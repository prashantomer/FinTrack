# == Schema Information
#
# Table name: term_accounts
#
#  id                :bigint           not null, primary key
#  account_number    :string(100)
#  account_type      :string           not null
#  amount            :decimal(14, 2)   not null
#  balance           :decimal(14, 2)   default(0.0), not null
#  closed_amount     :decimal(14, 2)
#  closed_date       :date
#  interest_rate     :decimal(5, 2)    not null
#  is_active         :boolean          default(TRUE), not null
#  maturity_amount   :decimal(14, 2)   not null
#  maturity_date     :date             not null
#  notes             :text
#  open_date         :date             not null
#  tenure_days       :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  parent_account_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_term_accounts_on_parent_account_id  (parent_account_id)
#  index_term_accounts_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_account_id => accounts.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class TermAccount < ApplicationRecord
  class Error < StandardError; end

  audited only: [ :balance ]

  has_one :import_record, as: :importable, dependent: :nullify

  belongs_to :user
  belongs_to :parent_account, class_name: "Account"

  enum :account_type, { fd: "fd", ppf: "ppf" }, validate: true

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }

  validates :amount,          presence: true, numericality: { greater_than: 0 }
  validates :open_date,       presence: true
  validates :interest_rate,   presence: true
  validates :maturity_date,   presence: true
  validates :maturity_amount, presence: true
  validates :tenure_days,     presence: true, if: :fd?

  before_validation :apply_defaults, on: :create

  def closed?
    !is_active
  end

  def deposit!(amount)
    raise Error, "Term account is closed" if closed?
    update!(balance: balance + amount)
  end

  def close!(closed_date:, closed_amount:)
    raise Error, "Term account is already closed" if closed?
    # Stamp the audit row so the Balance History sidebar can label this
    # "Account closed" instead of an anonymous "Balance update".
    self.audit_comment = "close:term_account_#{id}"
    update!(closed_date: closed_date, closed_amount: closed_amount, balance: 0, is_active: false)
  end

  private

  def apply_defaults
    self.account_number ||= if fd?
      Time.current.strftime("FD#%Y%m%d%H%M")
    else
      Time.current.strftime("PPF#%Y%m%d%H%M")
    end

    if maturity_date.nil? && open_date
      self.maturity_date = if fd? && tenure_days
        open_date + tenure_days.days
      elsif ppf?
        open_date >> (15 * 12)
      end
    end

    if fd? && maturity_amount.nil? && amount && interest_rate && tenure_days
      years = tenure_days.to_f / 365
      self.maturity_amount = (amount * (1 + interest_rate / 400.0) ** (4 * years)).round(2)
    end
  end
end
