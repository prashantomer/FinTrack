class TransactionSerializer < BaseSerializer
  def self.attributes(r)
    {
      id:                  r.id,
      public_id:           r.public_id,
      amount:              r.amount,
      type:                r.transaction_type,
      transaction_type:    r.transaction_type,
      description:         r.description,
      date:                r.date,
      tags:                r.tags,
      bank_ref:            r.bank_ref,
      is_active:           r.is_active,
      linked_account_type: r.linked_account_type&.underscore,
      linked_account_id:   r.linked_account_id,
      instrument_id:       r.instrument_id,
      created_at:          r.created_at
    }
  end
end
