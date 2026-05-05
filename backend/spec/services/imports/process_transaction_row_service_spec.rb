require "rails_helper"

RSpec.describe Imports::ProcessTransactionRowService, type: :service do
  let(:user)    { create(:user) }
  let(:bank)    { create(:bank) }
  let(:account) { create(:account, user: user, bank: bank, nickname: "My Savings", balance: 10_000) }
  let(:batch)   { create(:import_batch, :transactions, user: user) }

  def build_row(overrides = {})
    {
      date:                     "2024-03-01",
      amount:                   "2500",
      type:                     "credit",
      linked_account_nickname:  nil,
      description:              "Salary credit",
      tags:                     nil,
      bank_ref:                 nil
    }.merge(overrides)
  end

  def call_service(idx: 0, **row_overrides)
    described_class.new(batch, build_row(row_overrides), idx).call
  end

  describe "#call" do
    describe "basic transaction creation" do
      it "creates a Transaction record" do
        expect { call_service }.to change(Transaction, :count).by(1)
      end

      it "sets the correct amount" do
        call_service
        expect(Transaction.last.amount).to eq(2_500.0)
      end

      it "sets the correct transaction_type to credit" do
        call_service
        expect(Transaction.last.transaction_type).to eq("credit")
      end

      it "sets the correct date" do
        call_service
        expect(Transaction.last.date).to eq(Date.new(2024, 3, 1))
      end

      it "sets the description" do
        call_service
        expect(Transaction.last.description).to eq("Salary credit")
      end

      it "creates a debit transaction" do
        call_service(type: "debit")
        expect(Transaction.last.transaction_type).to eq("debit")
      end

      it "accepts DD/MM/YYYY date format" do
        call_service(date: "01/03/2024")
        expect(Transaction.last.date).to eq(Date.new(2024, 3, 1))
      end

      it "accepts DD-MM-YYYY date format" do
        call_service(date: "01-03-2024")
        expect(Transaction.last.date).to eq(Date.new(2024, 3, 1))
      end
    end

    describe "account linking" do
      before { account }  # ensure account is created

      it "links the transaction when linked_account_nickname matches" do
        call_service(linked_account_nickname: "My Savings")
        txn = Transaction.last
        expect(txn.linked_account).to eq(account)
      end

      it "updates the account balance when a credit is linked" do
        call_service(linked_account_nickname: "My Savings", amount: "1000", type: "credit")
        expect(account.reload.balance).to eq(11_000.0)
      end

      it "updates the account balance when a debit is linked" do
        call_service(linked_account_nickname: "My Savings", amount: "500", type: "debit")
        expect(account.reload.balance).to eq(9_500.0)
      end

      it "leaves linked_account nil when nickname is blank" do
        call_service(linked_account_nickname: nil)
        expect(Transaction.last.linked_account).to be_nil
      end

      it "leaves linked_account nil when nickname does not match any account" do
        call_service(linked_account_nickname: "Non Existent Account")
        expect(Transaction.last.linked_account).to be_nil
      end

      it "performs case-insensitive nickname matching" do
        call_service(linked_account_nickname: "MY SAVINGS")
        expect(Transaction.last.linked_account).to eq(account)
      end
    end

    describe "tags parsing" do
      it "parses comma-separated tags into an array" do
        call_service(tags: "food, travel, misc")
        expect(Transaction.last.tags).to eq(%w[food travel misc])
      end

      it "leaves tags nil when blank" do
        call_service(tags: nil)
        expect(Transaction.last.tags).to be_nil
      end

      it "handles a single tag" do
        call_service(tags: "groceries")
        expect(Transaction.last.tags).to eq([ "groceries" ])
      end
    end

    describe "ImportRecord creation" do
      it "creates an ImportRecord with status :ok" do
        expect { call_service }.to change(ImportRecord, :count).by(1)
      end

      it "sets the import record status to ok" do
        call_service
        expect(ImportRecord.last.status).to eq("ok")
      end

      it "sets the correct row_index" do
        call_service(idx: 5)
        expect(ImportRecord.last.row_index).to eq(5)
      end

      it "sets importable to the created transaction" do
        call_service
        expect(ImportRecord.last.importable).to eq(Transaction.last)
      end

      it "notes the linked account in the import record" do
        account  # ensure account exists
        call_service(linked_account_nickname: "My Savings")
        expect(ImportRecord.last.notes).to include("My Savings")
      end

      it "notes nil when no account is linked" do
        call_service(linked_account_nickname: nil)
        expect(ImportRecord.last.notes).to be_nil
      end
    end

    describe "error cases" do
      it "raises when date is blank" do
        expect { call_service(date: "") }.to raise_error(/date is required/)
      end

      it "raises when date format is unrecognisable" do
        expect { call_service(date: "March 1 2024") }.to raise_error(/Invalid date/)
      end

      it "raises when type is not credit or debit" do
        expect { call_service(type: "transfer") }.to raise_error(/type must be 'credit' or 'debit'/)
      end

      it "raises when amount is zero" do
        expect { call_service(amount: "0") }.to raise_error(/amount must be greater than 0/)
      end

      it "raises when amount is negative" do
        expect { call_service(amount: "-100") }.to raise_error(/amount must be greater than 0/)
      end
    end
  end
end
