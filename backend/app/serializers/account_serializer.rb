class AccountSerializer < BaseSerializer
  def self.attributes(r)
    bank = assoc(r, :bank)
    {
      id:             r.id,
      nickname:       r.nickname,
      account_type:   r.account_type,
      balance:        r.balance,
      account_number: r.account_number,
      open_date:      r.open_date,
      closed_date:    r.closed_date,
      closed_amount:  r.closed_amount,
      bank_id:        r.bank_id,
      bank:           bank ? { id: bank.id, name: bank.name, short_name: bank.short_name } : nil,
      created_at:     r.created_at
    }
  end
end
