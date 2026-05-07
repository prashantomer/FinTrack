# == Schema Information
#
# Table name: banks
#
#  id         :bigint           not null, primary key
#  is_system  :boolean          default(FALSE), not null
#  name       :string(100)      not null
#  short_name :string(6)        not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_banks_on_short_name  (short_name) UNIQUE
#
FactoryBot.define do
  sequence(:bank_short_name) { |n| "BNK#{n.to_s.rjust(3, "0")}" }
  sequence(:bank_name)       { |n| "Bank #{n}" }

  factory :bank do
    name       { generate(:bank_name) }
    short_name { generate(:bank_short_name) }
    is_system  { false }
  end
end
