# == Schema Information
#
# Table name: import_batches
#
#  id                  :bigint           not null, primary key
#  duplicate_rows      :integer          default(0), not null
#  expected_balance    :decimal(14, 2)
#  failed_rows         :integer          default(0), not null
#  file_name           :string           not null
#  import_number       :integer          not null
#  import_type         :string           not null
#  import_version      :integer          default(1), not null
#  linked_account_type :string
#  on_balance_mismatch :string           default("ask"), not null
#  processed_rows      :integer          default(0), not null
#  status              :string           default("pending"), not null
#  total_rows          :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  linked_account_id   :bigint
#  sidekiq_job_id      :string
#  user_id             :bigint           not null
#
# Indexes
#
#  idx_import_batches_user_id_import_number  (user_id,import_number) UNIQUE
#  idx_import_batches_version                (user_id,import_type,import_version) UNIQUE
#  index_import_batches_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
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
