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
#  open_date      :date             not null
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
FactoryBot.define do
  sequence(:account_nickname) { |n| "Account #{n}" }

  factory :account do
    association :user
    association :bank

    nickname     { generate(:account_nickname) }
    account_type { "savings" }
    balance      { 10_000.00 }
    # Far enough in the past that any test-fixture transaction date is
    # safely after the account's open_date validation.
    open_date    { Date.new(2000, 1, 1) }
  end
end
