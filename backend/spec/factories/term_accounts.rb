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
