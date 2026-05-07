# == Schema Information
#
# Table name: import_records
#
#  id              :bigint           not null, primary key
#  importable_type :string
#  notes           :text
#  row_index       :integer          not null
#  status          :string           default("ok"), not null
#  created_at      :datetime         not null
#  import_batch_id :bigint           not null
#  importable_id   :bigint
#
# Indexes
#
#  idx_import_records_importable            (importable_type,importable_id)
#  index_import_records_on_import_batch_id  (import_batch_id)
#
# Foreign Keys
#
#  fk_rails_...  (import_batch_id => import_batches.id) ON DELETE => cascade
#
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
