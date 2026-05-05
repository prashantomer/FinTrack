FactoryBot.define do
  factory :user_instrument do
    association :user
    association :instrument
  end
end
