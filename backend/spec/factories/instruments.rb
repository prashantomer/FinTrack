# == Schema Information
#
# Table name: instruments
#
#  id              :bigint           not null, primary key
#  exchange        :string(20)
#  fund_house      :string(100)
#  investment_type :string           not null
#  isin            :string(20)
#  last_price      :decimal(15, 4)
#  last_price_at   :datetime
#  name            :string(255)      not null
#  ticker_symbol   :string(20)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_instruments_on_investment_type  (investment_type)
#  index_instruments_on_name             (name)
#
FactoryBot.define do
  sequence(:instrument_name)   { |n| "Instrument #{n}" }
  sequence(:instrument_ticker) { |n| "TKR#{n}" }
  sequence(:instrument_isin)   { |n| "IN#{n.to_s.rjust(10, "0")}" }

  factory :instrument do
    name            { generate(:instrument_name) }
    investment_type { "stock" }
    ticker_symbol   { generate(:instrument_ticker) }
    isin            { generate(:instrument_isin) }

    trait :mutual_fund do
      investment_type { "mutual_fund" }
      fund_house      { "Test Fund House" }
      ticker_symbol   { nil }
      isin            { generate(:instrument_isin) }
    end
  end
end
