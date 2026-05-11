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

  describe "blank-account opening balance seed" do
    let(:blank_account) { create(:account, user: user, nickname: "ICICI Blank", balance: 0, open_date: Date.new(2026, 3, 1)) }

    let(:csv_text) do
      # First row's balance_after is 4,500 after a 500 debit → opening 5,000.
      # Then a 1,000 credit takes it to 5,500.
      <<~CSV
        date,amount,type,linked_account_nickname,description,tags,bank_ref,balance_after
        2026-04-01,500.00,debit,ICICI Blank,Coffee,,REF-A,4500.00
        2026-04-02,1000.00,credit,ICICI Blank,Refund,,REF-B,5500.00
      CSV
    end

    let(:batch) do
      b = create(:import_batch,
                 user:                user,
                 import_type:         "transactions",
                 file_name:           "blank.csv",
                 linked_account_type: "Account",
                 linked_account_id:   blank_account.id)
      b.file.attach(io: StringIO.new(csv_text), filename: "blank.csv", content_type: "text/csv")
      b
    end

    it "seeds an opening Transaction and leaves the account reconciled" do
      described_class.new.perform(batch.id)
      batch.reload
      blank_account.reload

      opening = blank_account.user.transactions
                             .where(linked_account_type: "Account", linked_account_id: blank_account.id)
                             .where("'opening' = ANY(tags)")
                             .first
      expect(opening).to be_present
      expect(opening.amount.to_f).to eq(5000.00)
      expect(opening.transaction_type).to eq("credit")
      expect(opening.date).to eq(blank_account.open_date)
      expect(blank_account.balance.to_f).to eq(5500.00)
      expect(batch.status).to eq("completed")
    end

    it "skips seeding when the first row would be a duplicate ON THE TARGET account" do
      # The anchor-dup check defends against re-importing the same statement
      # into the same account: if row 1 already exists on that account by the
      # full dedup tuple, the seed would land but the row wouldn't, leaving
      # the ledger off by that row's delta.
      create(:transaction, user: user, linked_account: blank_account,
             transaction_type: "debit", amount: 500, date: Date.new(2026, 4, 1),
             bank_ref: "REF-A", source: "imported")

      described_class.new.perform(batch.id)

      opening = user.transactions.where("'opening' = ANY(tags)").first
      expect(opening).to be_nil
      # Pre-existing row stays; row 1 in the file dedups; row 2 lands on top.
      # Balance: 0 (start) - 500 (pre-existing) + 1000 (row 2) = 500.
      expect(blank_account.reload.balance.to_f).to eq(500.00)
    end

    it "skips seeding when the account already has transactions" do
      create(:transaction, user: user, linked_account: blank_account,
             transaction_type: "credit", amount: 100, date: Date.new(2026, 3, 15))
      starting = blank_account.reload.balance.to_f

      described_class.new.perform(batch.id)

      opening = user.transactions.where("'opening' = ANY(tags)").first
      expect(opening).to be_nil
      # Only the two imported rows applied, no opening seed.
      expect(blank_account.reload.balance.to_f).to eq(starting - 500 + 1000)
    end
  end

  # Note: ICICI-format .xls coverage lives elsewhere (or pending a synthetic
  # fixture). We deliberately don't commit a real bank-statement file to the
  # repo. The canonical CSV path above covers the rest of the job behaviour
  # (dispatch, dedup ladder, batch finalisation).
end
