# == Schema Information
#
# Table name: holdings
#
#  id                  :bigint           not null, primary key
#  avg_buy_price       :decimal(14, 4)
#  buy_lots            :integer
#  current_value       :decimal(14, 2)
#  folio_number        :string(50)
#  is_closed           :boolean          default(FALSE), not null
#  last_calculated_at  :datetime
#  notes               :text
#  realized_gain       :decimal(14, 2)
#  sell_lots           :integer
#  total_invested      :decimal(14, 2)
#  total_units         :decimal(15, 4)
#  type                :string           default("Folio"), not null
#  unrealized_gain     :decimal(14, 2)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  platform_account_id :bigint           not null
#  user_id             :bigint           not null
#  user_instrument_id  :bigint           not null
#
# Indexes
#
#  index_holdings_on_platform_account_id  (platform_account_id)
#  index_holdings_on_type                 (type)
#  index_holdings_on_user_id              (user_id)
#  index_holdings_on_user_instrument_id   (user_instrument_id)
#  uq_holding_user_instrument_account     (user_instrument_id,platform_account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (platform_account_id => platform_accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (user_instrument_id => user_instruments.id) ON DELETE => cascade
#
class Holding < ApplicationRecord
  # STI base. Two subclasses:
  #   Folio          — mutual-fund holdings (carry a folio_number per AMC)
  #   EquityHolding  — stock/equity holdings (no per-instrument identifier)
  #
  # Each row represents one (user_instrument × platform_account) position and
  # caches the latest aggregated stats so the API can read a position summary
  # without re-aggregating Investment lots on every request. Stats are kept up
  # to date by Holdings::RefreshService, invoked from Investment callbacks.
  self.inheritance_column = :type

  belongs_to :user
  belongs_to :user_instrument
  belongs_to :platform_account

  validates :user_instrument_id, uniqueness: { scope: :platform_account_id }

  scope :open,       -> { where(is_closed: false) }
  scope :closed,     -> { where(is_closed: true) }
  scope :for_user,   ->(u) { where(user: u) }
  scope :for_instrument, ->(ui_id) { where(user_instrument_id: ui_id) }
  scope :folios,     -> { where(type: "Folio") }
  scope :equities,   -> { where(type: "EquityHolding") }

  def stale?
    last_calculated_at.nil? || last_calculated_at < 1.minute.ago
  end
end
