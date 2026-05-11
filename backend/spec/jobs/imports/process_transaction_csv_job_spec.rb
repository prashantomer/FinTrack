require "rails_helper"

RSpec.describe Imports::ProcessTransactionCsvJob, type: :job do
  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user, nickname: "HDFC Primary") }

  describe "canonical CSV" do
    let(:csv_text) do
      <<~CSV
        date,amount,type,linked_account_nickname,description,tags,bank_ref
        2026-04-01,1000.00,credit,HDFC Primary,Salary,,REF-001
        2026-04-02,250.00,debit,HDFC Primary,Coffee,,
      CSV
    end

    let(:batch) do
      b = create(:import_batch, user: user, import_type: "transactions", file_name: "test.csv")
      b.file.attach(io: StringIO.new(csv_text), filename: "test.csv", content_type: "text/csv")
      b
    end

    it "creates a Transaction per row and finalises the batch as completed" do
      account # touch
      described_class.new.perform(batch.id)
      batch.reload
      expect(batch.status).to eq("completed")
      expect(batch.total_rows).to eq(2)
      expect(batch.processed_rows).to eq(2)
      expect(batch.failed_rows).to    eq(0)
      expect(user.transactions.where(source: "imported").count).to eq(2)
    end
  end

  # Note: ICICI-format .xls coverage lives elsewhere (or pending a synthetic
  # fixture). We deliberately don't commit a real bank-statement file to the
  # repo. The canonical CSV path above covers the rest of the job behaviour
  # (dispatch, dedup ladder, batch finalisation).
end
