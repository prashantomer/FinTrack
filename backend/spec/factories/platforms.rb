FactoryBot.define do
  sequence(:platform_name)       { |n| "Platform #{n}" }
  sequence(:platform_short_name) { |n| "PLT#{n.to_s.rjust(3, "0")}" }

  factory :platform do
    name          { generate(:platform_name) }
    short_name    { generate(:platform_short_name) }
    platform_type { "broker" }
    is_system     { false }
  end
end
