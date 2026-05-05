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
      created_at:      r.created_at
    }
  end
end
