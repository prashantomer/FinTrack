FactoryBot.define do
  sequence(:import_file_name) { |n| "import_#{n}.csv" }

  factory :import_batch do
    association :user

    import_type { "investments" }
    file_name   { generate(:import_file_name) }
    status      { "pending" }
    total_rows  { 0 }
    processed_rows { 0 }
    failed_rows    { 0 }

    after(:build) do |batch|
      batch.file.attach(
        io: StringIO.new("investment_type,name\nstock,Acme Corp\n"),
        filename: batch.file_name,
        content_type: "text/csv"
      )
    end

    trait :transactions do
      import_type { "transactions" }
      after(:build) do |batch|
        batch.file.attach(
          io: StringIO.new("date,amount,type\n2024-01-01,1000,credit\n"),
          filename: batch.file_name,
          content_type: "text/csv"
        )
      end
    end

    trait :term_accounts do
      import_type { "term_accounts" }
      after(:build) do |batch|
        batch.file.attach(
          io: StringIO.new("account_type,amount,open_date\nfd,50000,2024-01-01\n"),
          filename: batch.file_name,
          content_type: "text/csv"
        )
      end
    end

    trait :processing do
      status { "processing" }
    end

    trait :completed do
      status      { "completed" }
      total_rows  { 5 }
      processed_rows { 5 }
      failed_rows    { 0 }
    end

    trait :failed do
      status { "failed" }
    end
  end
end
