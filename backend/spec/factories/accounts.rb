FactoryBot.define do
  sequence(:account_nickname) { |n| "Account #{n}" }

  factory :account do
    association :user
    association :bank

    nickname     { generate(:account_nickname) }
    account_type { "savings" }
    balance      { 10_000.00 }
    open_date    { Date.today - 1.year }
  end
end
