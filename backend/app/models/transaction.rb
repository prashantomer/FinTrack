class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :instrument,     optional: true
  belongs_to :linked_account, polymorphic: true, optional: true

  has_one :import_record, as: :importable, dependent: :nullify

  enum :transaction_type, { credit: "credit", debit: "debit" }, validate: true

  scope :active, -> { where(is_active: true) }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date,   presence: true

  after_create :apply_balance_delta

  private

  def apply_balance_delta
    return unless linked_account.present?
    # FD term accounts skip balance update — principal-based, not running balance
    return if linked_account.is_a?(TermAccount) && linked_account.fd?

    delta = credit? ? amount : -amount
    linked_account.increment!(:balance, delta)
  end
end
