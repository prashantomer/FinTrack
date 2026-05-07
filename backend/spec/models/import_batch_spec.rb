# == Schema Information
#
# Table name: import_batches
#
#  id             :bigint           not null, primary key
#  duplicate_rows :integer          default(0), not null
#  failed_rows    :integer          default(0), not null
#  file_name      :string           not null
#  import_type    :string           not null
#  import_version :integer          default(1), not null
#  processed_rows :integer          default(0), not null
#  status         :string           default("pending"), not null
#  total_rows     :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  sidekiq_job_id :string
#  user_id        :bigint           not null
#
# Indexes
#
#  idx_import_batches_version       (user_id,import_type,import_version) UNIQUE
#  index_import_batches_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe ImportBatch, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:import_records).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:import_batch) }

    it { is_expected.to validate_presence_of(:import_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:file_name) }

    it "is valid with all required attributes" do
      expect(subject).to be_valid
    end
  end

  describe "enums" do
    it "defines the correct import_type values" do
      expect(ImportBatch.import_types.keys).to contain_exactly("investments", "transactions", "term_accounts")
    end

    it "defines the correct status values" do
      expect(ImportBatch.statuses.keys).to contain_exactly("pending", "processing", "completed", "failed")
    end

    it "validates import_type" do
      batch = build(:import_batch, import_type: "invalid_type")
      expect(batch).not_to be_valid
    end

    it "validates status" do
      batch = build(:import_batch, status: "unknown")
      expect(batch).not_to be_valid
    end
  end

  describe "import_version auto-increment" do
    let(:user) { create(:user) }

    it "sets import_version to 1 for the first batch of a type" do
      batch = create(:import_batch, user: user, import_type: "investments")
      expect(batch.import_version).to eq(1)
    end

    it "increments import_version for subsequent batches of the same type" do
      create(:import_batch, user: user, import_type: "investments")
      second = create(:import_batch, user: user, import_type: "investments")
      expect(second.import_version).to eq(2)
    end

    it "resets version counter per import_type" do
      create(:import_batch, user: user, import_type: "investments")
      txn_batch = create(:import_batch, :transactions, user: user)
      expect(txn_batch.import_version).to eq(1)
    end

    it "maintains separate version counters across users" do
      other_user = create(:user)
      create(:import_batch, user: user, import_type: "investments")
      create(:import_batch, user: user, import_type: "investments")

      first_for_other = create(:import_batch, user: other_user, import_type: "investments")
      expect(first_for_other.import_version).to eq(1)
    end

    it "reaches version 3 after three batches of the same type" do
      3.times { create(:import_batch, user: user, import_type: "investments") }
      expect(ImportBatch.where(user: user, import_type: "investments").maximum(:import_version)).to eq(3)
    end
  end

  describe "#progress_pct" do
    context "when total_rows is zero" do
      it "returns 0" do
        batch = build(:import_batch, total_rows: 0, processed_rows: 0)
        expect(batch.progress_pct).to eq(0)
      end
    end

    context "when total_rows is positive" do
      it "calculates percentage correctly for half completion" do
        batch = build(:import_batch, total_rows: 10, processed_rows: 5)
        expect(batch.progress_pct).to eq(50)
      end

      it "returns 100 when all rows are processed" do
        batch = build(:import_batch, total_rows: 4, processed_rows: 4)
        expect(batch.progress_pct).to eq(100)
      end

      it "rounds to nearest integer" do
        # 1/3 ≈ 33
        batch = build(:import_batch, total_rows: 3, processed_rows: 1)
        expect(batch.progress_pct).to eq(33)
      end

      it "handles 0 processed rows" do
        batch = build(:import_batch, total_rows: 10, processed_rows: 0)
        expect(batch.progress_pct).to eq(0)
      end
    end
  end

  describe "status transitions" do
    it "starts as pending by default" do
      batch = create(:import_batch)
      expect(batch).to be_pending
    end

    it "can transition to processing" do
      batch = create(:import_batch)
      batch.update!(status: :processing)
      expect(batch).to be_processing
    end

    it "can transition to completed" do
      batch = create(:import_batch, :completed)
      expect(batch).to be_completed
    end

    it "can transition to failed" do
      batch = create(:import_batch, :failed)
      expect(batch).to be_failed
    end
  end
end
