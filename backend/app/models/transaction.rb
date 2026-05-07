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
