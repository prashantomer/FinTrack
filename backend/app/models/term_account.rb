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
