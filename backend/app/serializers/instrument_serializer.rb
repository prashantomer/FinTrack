# == Schema Information
#
# Table name: instruments
#
#  id              :bigint           not null, primary key
#  exchange        :string(20)
#  fund_house      :string(100)
#  investment_type :string           not null
#  isin            :string(20)
#  last_price      :decimal(15, 4)
#  last_price_at   :datetime
#  name            :string(255)      not null
#  ticker_symbol   :string(20)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_instruments_on_investment_type  (investment_type)
#  index_instruments_on_name             (name)
#
class InstrumentSerializer < BaseSerializer
  def self.attributes(r)
    {
      id:              r.id,
      name:            r.name,
      type:            r.investment_type,
      investment_type: r.investment_type,
      ticker_symbol:   r.ticker_symbol,
      isin:            r.isin,
      exchange:        r.exchange,
      fund_house:      r.fund_house,
      last_price:      r.last_price,
      last_price_at:   r.last_price_at,
      created_at:      r.created_at
    }
  end
end
