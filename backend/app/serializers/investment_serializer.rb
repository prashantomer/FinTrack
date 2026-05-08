# == Schema Information
#
# Table name: investments
#
#  id                    :bigint           not null, primary key
#  amount_invested       :decimal(14, 2)   not null
#  current_value         :decimal(14, 2)
#  folio_number          :string(50)
#  investment_type       :string           not null
#  lot_pnl_at            :datetime
#  lot_realized_gain     :decimal(14, 2)
#  lot_unrealized_gain   :decimal(14, 2)
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
class InvestmentSerializer < BaseSerializer
  def self.attributes(r)
    ui         = assoc(r, :user_instrument)
    instrument = ui&.instrument
    last_price = instrument&.last_price&.to_f
    qty        = (r.quantity || r.units)&.to_f

    # Live values derive from the instrument's last_price (NSE close / AMFI NAV)
    # — the manual `current_value` column is rarely populated for imported rows.
    live_current_value = if r.buy? && last_price && qty
      (last_price * qty).round(2)
    end
    live_gain = live_current_value && r.amount_invested ? (live_current_value - r.amount_invested.to_f).round(2) : nil
    live_gain_pct = if live_gain && r.amount_invested.to_f > 0
      ((live_gain / r.amount_invested.to_f) * 100).round(2)
    end

    {
      id:                       r.id,
      type:                     r.investment_type,
      investment_type:          r.investment_type,
      trade_type:               r.trade_type,
      name:                     r.name,
      amount_invested:          r.amount_invested,
      notes:                    r.notes,
      user_instrument_id:       r.user_instrument_id,
      instrument_id:            ui&.instrument_id,
      platform_account_id:      r.platform_account_id,
      quantity:                 r.quantity,
      units:                    r.units,
      price:                    r.price,
      order_id:                 r.order_id,
      trade_id:                 r.trade_id,
      folio_number:             r.folio_number,
      current_value:            r.current_value,
      instrument_last_price:    last_price,
      instrument_last_price_at: instrument&.last_price_at,
      live_current_value:       live_current_value,
      live_gain:                live_gain,
      live_gain_pct:            live_gain_pct,
      purchase_date:            r.purchase_date,
      created_at:               r.created_at
    }
  end
end
