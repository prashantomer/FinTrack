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
class HoldingSerializer < BaseSerializer
  def self.attributes(r)
    ui = assoc(r, :user_instrument)
    pa = assoc(r, :platform_account)
    {
      id:                   r.id,
      type:                 r.type,
      folio_number:         r.folio_number,
      user_id:              r.user_id,
      user_instrument_id:   r.user_instrument_id,
      platform_account_id:  r.platform_account_id,
      notes:                r.notes,

      # Quick-stat register — populated by Holdings::RefreshService
      buy_lots:             r.buy_lots,
      sell_lots:            r.sell_lots,
      total_units:          r.total_units,
      avg_buy_price:        r.avg_buy_price,
      total_invested:       r.total_invested,
      current_value:        r.current_value,
      unrealized_gain:      r.unrealized_gain,
      realized_gain:        r.realized_gain,
      is_closed:            r.is_closed,
      last_calculated_at:   r.last_calculated_at,

      created_at:           r.created_at,
      user_instrument:      ui ? UserInstrumentSerializer.one(ui) : nil,
      platform_account:     pa ? PlatformAccountSerializer.one(pa) : nil
    }
  end
end

# Subclass serializers reuse the same attribute set so the Responder middleware
# (which auto-resolves `<ClassName>Serializer`) finds one for both STI types.
FolioSerializer         = HoldingSerializer
EquityHoldingSerializer = HoldingSerializer
