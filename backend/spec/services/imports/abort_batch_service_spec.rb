require "rails_helper"

RSpec.describe Imports::AbortBatchService, type: :service do
  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user, nickname: "ICICI", balance: 0, open_date: Date.new(2026, 3, 1)) }

  describe "#call" do
    it "destroys :ok transactions and reverses their balance impact" do
      batch = create(:import_batch, user: user, import_type: "transactions",
                     linked_account_type: "Account", linked_account_id: account.id)

      txn = create(:transaction, user: user, linked_account: account,
                   transaction_type: "credit", amount: 1_000, date: Date.new(2026, 4, 1),
                   source: "imported")
      batch.import_records.create!(importable: txn, row_index: 0, status: :ok)

      account.reload
      starting_balance = account.balance.to_f

      described_class.new(batch).call

      expect(Transaction.exists?(txn.id)).to be false
      expect(account.reload.balance.to_f).to eq(starting_balance - 1_000)
      expect(batch.reload.status).to eq("failed")
    end

    it "purges the create + revert audit comments for destroyed txns" do
      batch = create(:import_batch, user: user, import_type: "transactions",
                     linked_account_type: "Account", linked_account_id: account.id)
      txn = nil
      Audited.audit_class.as_user(user) do
        txn = Transaction.create!(
          user: user, source: "imported", amount: 1_000,
          transaction_type: "credit", date: Date.new(2026, 4, 1),
          linked_account_type: "Account", linked_account_id: account.id
        )
      end
      batch.import_records.create!(importable: txn, row_index: 0, status: :ok)

      # Sanity: the create wrote a "txn:N" audit on the account.
      expect(Audited::Audit.where(auditable: account, comment: "txn:#{txn.id}")).to exist

      described_class.new(batch).call

      # Neither the create nor the revert comment should remain.
      expect(Audited::Audit.where(auditable: account, comment: "txn:#{txn.id}")).not_to exist
      expect(Audited::Audit.where(auditable: account, comment: "revert:txn_#{txn.id}")).not_to exist
    end

    it "leaves pre-existing duplicates untouched (only :ok records get destroyed)" do
      # Pre-existing real transaction — e.g. from a prior import or manual entry.
      pre_existing = create(:transaction, user: user, linked_account: account,
                            transaction_type: "credit", amount: 50_000,
                            date: Date.new(2026, 3, 15), source: "imported",
                            bank_ref: "ICICI:UPI/OLD-REF")
      balance_after_seed = account.reload.balance.to_f
      expect(balance_after_seed).to eq(50_000)

      # New batch where one row collided with `pre_existing` (registered as :skipped
      # with importable = pre_existing), one row succeeded.
      batch = create(:import_batch, user: user, import_type: "transactions",
                     linked_account_type: "Account", linked_account_id: account.id)
      new_txn = create(:transaction, user: user, linked_account: account,
                       transaction_type: "debit", amount: 500, date: Date.new(2026, 4, 1),
                       source: "imported", bank_ref: "ICICI:UPI/NEW-REF")
      batch.import_records.create!(importable: new_txn,      row_index: 0, status: :ok)
      batch.import_records.create!(importable: pre_existing, row_index: 1, status: :skipped,
                                   notes: "Duplicate of Transaction ##{pre_existing.id}")

      described_class.new(batch).call

      # The :ok row is gone; its 500 debit is reversed.
      expect(Transaction.exists?(new_txn.id)).to be false
      # The :skipped row's underlying pre-existing transaction MUST survive,
      # and its 50,000 credit must NOT be reversed.
      expect(Transaction.exists?(pre_existing.id)).to be true
      expect(account.reload.balance.to_f).to eq(50_000)
    end
  end
end
