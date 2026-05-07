# == Schema Information
#
# Table name: platforms
#
#  id            :bigint           not null, primary key
#  is_system     :boolean          default(FALSE), not null
#  name          :string(100)      not null
#  platform_type :string           not null
#  short_name    :string(20)       not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_platforms_on_short_name  (short_name) UNIQUE
#
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
