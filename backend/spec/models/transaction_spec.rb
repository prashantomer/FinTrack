require "rails_helper"

RSpec.describe Transaction, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:instrument).optional }
    it { is_expected.to belong_to(:linked_account).optional }
    it { is_expected.to have_one(:import_record) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:date) }

    it "requires amount to be greater than 0" do
      txn = build(:transaction, amount: 0)
      expect(txn).not_to be_valid
      expect(txn.errors[:amount]).to be_present
    end

    it "rejects negative amounts" do
      txn = build(:transaction, amount: -100)
      expect(txn).not_to be_valid
    end

    it "accepts positive amounts" do
      txn = build(:transaction, amount: 1_000)
      expect(txn).to be_valid
    end

    it "validates transaction_type enum" do
      txn = build(:transaction, transaction_type: "transfer")
      expect(txn).not_to be_valid
    end
  end

  describe "enums" do
    it "defines credit and debit" do
      expect(Transaction.transaction_types.keys).to contain_exactly("credit", "debit")
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }

    it ".active returns only active transactions" do
      active_txn   = create(:transaction, user: user, is_active: true)
      inactive_txn = create(:transaction, user: user, is_active: false)

      result = Transaction.active
      expect(result).to include(active_txn)
      expect(result).not_to include(inactive_txn)
    end
  end

  describe "after_create :apply_balance_delta" do
    let(:user)    { create(:user) }
    let(:bank)    { create(:bank) }
    let(:account) { create(:account, user: user, bank: bank, balance: 5_000.00) }

    context "credit transaction with a linked savings account" do
      it "increases the account balance" do
        create(:transaction, user: user, transaction_type: "credit", amount: 1_000, linked_account: account)
        expect(account.reload.balance).to eq(6_000.00)
      end
    end

    context "debit transaction with a linked savings account" do
      it "decreases the account balance" do
        create(:transaction, user: user, transaction_type: "debit", amount: 500, linked_account: account)
        expect(account.reload.balance).to eq(4_500.00)
      end
    end

    context "when linked_account is nil" do
      it "does not raise and leaves no balance changes" do
        expect {
          create(:transaction, user: user, transaction_type: "credit", amount: 200, linked_account: nil)
        }.not_to raise_error
      end
    end

    context "when linked_account is an FD term account" do
      let(:term_account) do
        create(:term_account, user: user, parent_account: account,
               account_type: "fd", amount: 10_000, balance: 10_000)
      end

      it "skips balance update on the FD term account" do
        initial_balance = term_account.balance
        create(:transaction, user: user, transaction_type: "credit", amount: 10_000,
               linked_account: term_account)
        expect(term_account.reload.balance).to eq(initial_balance)
      end
    end

    context "when linked_account is a PPF term account" do
      let(:ppf_account) do
        create(:term_account, :ppf, user: user, parent_account: account,
               amount: 1_000, balance: 1_000, maturity_amount: 0)
      end

      it "increases PPF balance on credit" do
        create(:transaction, user: user, transaction_type: "credit", amount: 500,
               linked_account: ppf_account)
        expect(ppf_account.reload.balance).to eq(1_500.00)
      end
    end

    context "multiple transactions on the same account" do
      it "accumulates balance changes correctly" do
        create(:transaction, user: user, transaction_type: "credit", amount: 2_000, linked_account: account)
        create(:transaction, user: user, transaction_type: "debit",  amount: 700,  linked_account: account)
        expect(account.reload.balance).to eq(6_300.00)
      end
    end
  end
end
