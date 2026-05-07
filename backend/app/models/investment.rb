# == Schema Information
#
# Table name: investments
#
#  id                    :bigint           not null, primary key
#  amount_invested       :decimal(14, 2)   not null
#  current_value         :decimal(14, 2)
#  folio_number          :string(50)
#  investment_type       :string           not null
#  name                  :string(255)      not null
#  notes                 :text
#  price                 :decimal(14, 4)
#  purchase_date         :date             not null
#  quantity              :decimal(12, 4)
#  trade_type            :string           default("buy"), not null
#  units                 :decimal(12, 4)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  order_id              :string(64)
#  platform_account_id   :bigint
#  trade_id              :string(64)
#  transaction_public_id :uuid
#  user_id               :bigint           not null
#  user_instrument_id    :bigint
#
# Indexes
#
#  index_investments_on_investment_type        (investment_type)
#  index_investments_on_order_id               (order_id)
#  index_investments_on_order_id_and_trade_id  (order_id,trade_id)
#  index_investments_on_platform_account_id    (platform_account_id)
#  index_investments_on_trade_id               (trade_id)
#  index_investments_on_trade_type             (trade_type)
#  index_investments_on_transaction_public_id  (transaction_public_id)
#  index_investments_on_user_id                (user_id)
#  index_investments_on_user_instrument_id     (user_instrument_id)
#
# Foreign Keys
#
#  fk_rails_...  (platform_account_id => platform_accounts.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (user_instrument_id => user_instruments.id) ON DELETE => nullify
#
class Investment < ApplicationRecord
  belongs_to :user
  belongs_to :platform_account, optional: true
  belongs_to :user_instrument,  optional: true
  has_one    :import_record, as: :importable, dependent: :nullify

  enum :investment_type, { stock: "stock", mutual_fund: "mutual_fund" }, validate: true
  enum :trade_type,      { buy:   "buy",   sell:        "sell" },        validate: true

  validates :name,            presence: true
  validates :amount_invested, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_date,   presence: true

  scope :buys,  -> { where(trade_type: "buy") }
  scope :sells, -> { where(trade_type: "sell") }

  # Keep the cached Holding row in sync after every lot mutation. Runs in
  # Sidekiq so the request thread returns immediately. Bulk callers (CSV
  # import, API bulk endpoints) can set `Current.skip_holding_refresh = true`
  # and enqueue a single sweep at the end of the batch.
  after_save_commit    :enqueue_holding_refresh
  after_destroy_commit :enqueue_holding_refresh

  def enqueue_holding_refresh
    return if Current.skip_holding_refresh
    return unless user_instrument_id && platform_account_id
    Holdings::RefreshJob.perform_later(user_id, user_instrument_id, platform_account_id)
  end

  # Signed quantity: buy contributes +qty, sell contributes -qty. Used by holdings aggregation.
  def signed_quantity
    base = quantity || units || 0
    buy? ? base.to_f : -base.to_f
  end

  # Signed amount: buy contributes +invested, sell contributes -proceeds.
  # Net amount_invested across a position = total cash deployed minus cash returned.
  def signed_amount_invested
    buy? ? amount_invested.to_f : -amount_invested.to_f
  end
end
