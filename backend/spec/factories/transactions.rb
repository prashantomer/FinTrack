FactoryBot.define do
  factory :transaction do
    association :user

    amount           { 1_000.00 }
    transaction_type { "credit" }
    date             { Date.today }
    description      { "Test transaction" }
    is_active        { true }

    trait :debit do
      transaction_type { "debit" }
    end

    trait :with_account do
      association :linked_account, factory: :account
    end
  end
end
