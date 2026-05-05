class InvestmentSerializer < BaseSerializer
  def self.attributes(r)
    ui = assoc(r, :user_instrument)
    {
      id:                  r.id,
      type:                r.investment_type,
      investment_type:     r.investment_type,
      name:                r.name,
      amount_invested:     r.amount_invested,
      notes:               r.notes,
      user_instrument_id:  r.user_instrument_id,
      instrument_id:       ui&.instrument_id,
      platform_account_id: r.platform_account_id,
      quantity:            r.quantity,
      buy_price:           r.buy_price,
      units:               r.units,
      nav_at_purchase:     r.nav_at_purchase,
      folio_number:        r.folio_number,
      current_value:       r.current_value,
      purchase_date:       r.purchase_date,
      created_at:          r.created_at
    }
  end
end
