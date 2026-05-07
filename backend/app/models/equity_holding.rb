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
class EquityHolding < Holding
  # Stock holding. No per-instrument folio identifier (stocks live in a demat
  # account, identified by DP+Client ID — that's at the platform_account level
  # rather than per scrip).
end
