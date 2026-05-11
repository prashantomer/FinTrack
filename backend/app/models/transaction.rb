# == Schema Information
#
# Table name: transactions
#
#  id                  :bigint           not null, primary key
#  amount              :decimal(12, 2)   not null
#  bank_ref            :string(100)
#  date                :date             not null
#  description         :string(500)
#  is_active           :boolean          default(TRUE), not null
#  linked_account_type :string
#  source              :string           default("manual"), not null
#  tags                :string           is an Array
#  transaction_type    :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  instrument_id       :bigint
#  linked_account_id   :integer
#  public_id           :uuid
#  user_id             :bigint           not null
#
# Indexes
#
#  index_transactions_on_date_and_id          (date,id)
#  index_transactions_on_instrument_id        (instrument_id)
#  index_transactions_on_linked_account_id    (linked_account_id)
#  index_transactions_on_linked_account_type  (linked_account_type)
#  index_transactions_on_public_id            (public_id) UNIQUE
#  index_transactions_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (instrument_id => instruments.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :instrument,     optional: true
  belongs_to :linked_account, polymorphic: true, optional: true

  has_one :import_record, as: :importable, dependent: :nullify

  enum :transaction_type, { credit: "credit", debit: "debit" }, validate: true
  # `manual` rows came from the API/UI and remain editable (description + tags
  # only — never amount/type, which would desync the linked account balance).
  # `imported` rows came through Imports::* and are frozen.
  enum :source,           { manual: "manual", imported: "imported" }, validate: true

  scope :active, -> { where(is_active: true) }

  def editable?
    manual?
  end

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date,   presence: true
  validate  :date_after_account_open_date

  after_create :apply_balance_delta

  private

  # `open_date` is a hard cutoff. Anything prior to it must be folded into the
  # opening deposit (a regular credit dated on the open date). Transactions
  # dated before the open date are rejected at validation time.
  def date_after_account_open_date
    return unless date.present?
    return unless linked_account.is_a?(Account)
    return unless linked_account.open_date.present?
    return unless date < linked_account.open_date

    errors.add(:date, "is before account open date (#{linked_account.open_date})")
  end

  def apply_balance_delta
    return unless linked_account.present?
    # FD term accounts skip balance update — principal-based, not running balance
    return if linked_account.is_a?(TermAccount) && linked_account.fd?

    delta = credit? ? amount : -amount
    # `update!` (not `increment!`) so the `audited` gem captures the before/
    # after balance. `increment!` does an atomic SQL bump and skips callbacks,
    # so the audit log would stay empty for every imported / manual txn.
    # `audit_comment` carries the source txn id so the Account audit-log UI
    # can show "Bank transfer · ₹5,000 · UTR123".
    Audited.audit_class.as_user(user) do
      linked_account.audit_comment = "txn:#{id}"
      linked_account.update!(balance: linked_account.balance + delta)
    end
  end
end
