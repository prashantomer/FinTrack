FactoryBot.define do
  sequence(:bank_short_name) { |n| "BNK#{n.to_s.rjust(3, "0")}" }
  sequence(:bank_name)       { |n| "Bank #{n}" }

  factory :bank do
    name       { generate(:bank_name) }
    short_name { generate(:bank_short_name) }
    is_system  { false }
  end
end
