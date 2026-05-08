# == Schema Information
#
# Table name: users
#
#  id              :bigint           not null, primary key
#  currency_code   :string           default("INR"), not null
#  currency_locale :string           default("en-IN"), not null
#  email           :string           not null
#  first_name      :string           not null
#  is_active       :boolean          default(TRUE), not null
#  is_superuser    :boolean          default(FALSE), not null
#  last_name       :string           not null
#  password_digest :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
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
