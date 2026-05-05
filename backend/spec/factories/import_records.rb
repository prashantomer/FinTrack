FactoryBot.define do
  factory :import_record do
    association :import_batch

    row_index { 0 }
    status    { "ok" }
    notes     { nil }

    trait :error do
      status { "error" }
      notes  { "Something went wrong" }
    end

    trait :skipped do
      status { "skipped" }
      notes  { "Row skipped" }
    end
  end
end
