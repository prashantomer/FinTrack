FactoryBot.define do
  sequence(:investment_name) { |n| "Investment #{n}" }

  factory :investment do
    association :user

    name            { generate(:investment_name) }
    investment_type { "stock" }
    amount_invested { 5_000.00 }
    purchase_date   { Date.today - 30.days }

    trait :mutual_fund do
      investment_type { "mutual_fund" }
    end

    trait :with_platform_account do
      association :platform_account
    end

    trait :with_user_instrument do
      association :user_instrument
    end
  end
end
