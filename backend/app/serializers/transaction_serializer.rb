# == Schema Information
#
# Table name: transactions
#
#  id                  :bigint           not null, primary key
#  amount              :decimal(12, 2)   not null
#  bank_ref            :string(100)
#  date                :date             not null
#  description         :string(500)
#  is_active           :boolean          default(TRUE), not null
#  linked_account_type :string
#  source              :string           default("manual"), not null
#  tags                :string           is an Array
#  transaction_type    :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  instrument_id       :bigint
#  linked_account_id   :integer
#  public_id           :uuid
#  user_id             :bigint           not null
#
# Indexes
#
#  index_transactions_on_date_and_id          (date,id)
#  index_transactions_on_instrument_id        (instrument_id)
#  index_transactions_on_linked_account_id    (linked_account_id)
#  index_transactions_on_linked_account_type  (linked_account_type)
#  index_transactions_on_public_id            (public_id) UNIQUE
#  index_transactions_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (instrument_id => instruments.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class TransactionSerializer < BaseSerializer
  def self.attributes(r)
    {
      id:                  r.id,
      public_id:           r.public_id,
      source:              r.source,
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
