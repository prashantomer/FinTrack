# == Schema Information
#
# Table name: term_accounts
#
#  id                :bigint           not null, primary key
#  account_number    :string(100)
#  account_type      :string           not null
#  amount            :decimal(14, 2)   not null
#  balance           :decimal(14, 2)   default(0.0), not null
#  closed_amount     :decimal(14, 2)
#  closed_date       :date
#  interest_rate     :decimal(5, 2)    not null
#  is_active         :boolean          default(TRUE), not null
#  maturity_amount   :decimal(14, 2)   not null
#  maturity_date     :date             not null
#  notes             :text
#  open_date         :date             not null
#  tenure_days       :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  parent_account_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_term_accounts_on_parent_account_id  (parent_account_id)
#  index_term_accounts_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_account_id => accounts.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :term_account do
    association :user
    association :parent_account, factory: :account

    account_type  { "fd" }
    amount        { 50_000.00 }
    open_date     { Date.today - 90.days }
    interest_rate { 7.0 }
    tenure_days   { 365 }
    balance       { 50_000.00 }
    is_active     { true }
    # maturity_date and maturity_amount are auto-calculated via before_validation :apply_defaults

    trait :ppf do
      account_type  { "ppf" }
      tenure_days   { nil }
      # PPF maturity_amount must be provided (service passes 0 as default)
      maturity_amount { 0 }
    end
  end
end
