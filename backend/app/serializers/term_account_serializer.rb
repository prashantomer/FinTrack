# == Schema Information
#
# Table name: term_accounts
#
#  id                :bigint           not null, primary key
#  account_number    :string(100)
#  account_type      :string           not null
#  amount            :decimal(14, 2)   not null
#  balance           :decimal(14, 2)   default(0.0), not null
#  closed_amount     :decimal(14, 2)
#  closed_date       :date
#  interest_rate     :decimal(5, 2)    not null
#  is_active         :boolean          default(TRUE), not null
#  maturity_amount   :decimal(14, 2)   not null
#  maturity_date     :date             not null
#  notes             :text
#  open_date         :date             not null
#  tenure_days       :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  parent_account_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_term_accounts_on_parent_account_id  (parent_account_id)
#  index_term_accounts_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_account_id => accounts.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
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
