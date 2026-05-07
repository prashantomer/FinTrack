# == Schema Information
#
# Table name: accounts
#
#  id             :bigint           not null, primary key
#  account_number :string(50)
#  account_type   :string           default("savings"), not null
#  balance        :decimal(14, 2)   default(0.0), not null
#  closed_amount  :decimal(14, 2)
#  closed_date    :date
#  nickname       :string(100)      not null
#  open_date      :date
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  bank_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_accounts_on_bank_id  (bank_id)
#  index_accounts_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (bank_id => banks.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
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
