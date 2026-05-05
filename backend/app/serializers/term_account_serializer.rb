class TermAccountSerializer < BaseSerializer
  def self.attributes(r)
    parent = assoc(r, :parent_account)
    bank   = parent && parent.association(:bank).loaded? ? parent.bank : nil
    {
      id:                r.id,
      type:              r.account_type,
      account_type:      r.account_type,
      account_number:    r.account_number,
      amount:            r.amount,
      balance:           r.balance,
      interest_rate:     r.interest_rate,
      tenure_days:       r.tenure_days,
      open_date:         r.open_date,
      maturity_date:     r.maturity_date,
      maturity_amount:   r.maturity_amount,
      parent_account_id: r.parent_account_id,
      closed_date:       r.closed_date,
      closed_amount:     r.closed_amount,
      is_active:         r.is_active,
      notes:             r.notes,
      created_at:        r.created_at,
      bank:              bank ? { id: bank.id, name: bank.name, short_name: bank.short_name } : nil
    }
  end
end
