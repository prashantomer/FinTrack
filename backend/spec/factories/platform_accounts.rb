FactoryBot.define do
  sequence(:platform_account_nickname) { |n| "Platform Account #{n}" }

  factory :platform_account do
    association :user
    association :platform

    nickname { generate(:platform_account_nickname) }
  end
end
