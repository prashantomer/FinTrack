FactoryBot.define do
  sequence(:user_email) { |n| "user#{n}@example.com" }
  sequence(:first_name) { |n| "First#{n}" }
  sequence(:last_name)  { |n| "Last#{n}" }

  factory :user do
    email         { generate(:user_email) }
    first_name    { generate(:first_name) }
    last_name     { generate(:last_name) }
    password      { "password123" }
    currency_code   { "INR" }
    currency_locale { "en-IN" }
    is_active     { true }
    is_superuser  { false }
  end
end
