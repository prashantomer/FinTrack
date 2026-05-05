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
