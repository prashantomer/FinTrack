# == Schema Information
#
# Table name: investments
#
#  id                    :bigint           not null, primary key
#  amount_invested       :decimal(14, 2)   not null
#  current_value         :decimal(14, 2)
#  folio_number          :string(50)
#  investment_type       :string           not null
#  name                  :string(255)      not null
#  notes                 :text
#  price                 :decimal(14, 4)
#  purchase_date         :date             not null
#  quantity              :decimal(12, 4)
#  trade_type            :string           default("buy"), not null
#  units                 :decimal(12, 4)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  order_id              :string(64)
#  platform_account_id   :bigint
#  trade_id              :string(64)
#  transaction_public_id :uuid
#  user_id               :bigint           not null
#  user_instrument_id    :bigint
#
# Indexes
#
#  index_investments_on_investment_type        (investment_type)
#  index_investments_on_order_id               (order_id)
#  index_investments_on_order_id_and_trade_id  (order_id,trade_id)
#  index_investments_on_platform_account_id    (platform_account_id)
#  index_investments_on_trade_id               (trade_id)
#  index_investments_on_trade_type             (trade_type)
#  index_investments_on_transaction_public_id  (transaction_public_id)
#  index_investments_on_user_id                (user_id)
#  index_investments_on_user_instrument_id     (user_instrument_id)
#
# Foreign Keys
#
#  fk_rails_...  (platform_account_id => platform_accounts.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (user_instrument_id => user_instruments.id) ON DELETE => nullify
#
FactoryBot.define do
  sequence(:investment_name) { |n| "Investment #{n}" }

  factory :investment do
    association :user

    name            { generate(:investment_name) }
    investment_type { "stock" }
    trade_type      { "buy" }
    amount_invested { 5_000.00 }
    purchase_date   { Date.today - 30.days }

    trait :mutual_fund do
      investment_type { "mutual_fund" }
    end

    trait :sell do
      trade_type { "sell" }
    end

    trait :with_platform_account do
      association :platform_account
    end

    trait :with_user_instrument do
      association :user_instrument
    end
  end
end
