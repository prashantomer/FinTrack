# == Schema Information
#
# Table name: term_accounts
#
#  id                :bigint           not null, primary key
#  account_number    :string(100)
#  account_type      :string           not null
#  amount            :decimal(14, 2)   not null
#  balance           :decimal(14, 2)   default(0.0), not null
#  closed_amount     :decimal(14, 2)
#  closed_date       :date
#  interest_rate     :decimal(5, 2)    not null
#  is_active         :boolean          default(TRUE), not null
#  maturity_amount   :decimal(14, 2)   not null
#  maturity_date     :date             not null
#  notes             :text
#  open_date         :date             not null
#  tenure_days       :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  parent_account_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_term_accounts_on_parent_account_id  (parent_account_id)
#  index_term_accounts_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_account_id => accounts.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe TermAccount, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:parent_account).class_name("Account") }
    it { is_expected.to have_one(:import_record) }
  end

  describe "validations" do
    let(:user)    { create(:user) }
    let(:account) { create(:account, user: user) }

    subject do
      build(:term_account, user: user, parent_account: account,
            amount: 10_000, open_date: Date.today - 30.days,
            interest_rate: 7.0, tenure_days: 365)
    end

    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:open_date) }
    it { is_expected.to validate_presence_of(:interest_rate) }

    it "requires amount to be greater than 0" do
      ta = build(:term_account, user: user, parent_account: account, amount: 0)
      ta.valid?
      expect(ta.errors[:amount]).to be_present
    end

    it "validates account_type enum" do
      ta = build(:term_account, user: user, parent_account: account, account_type: "nps")
      expect(ta).not_to be_valid
    end

    context "FD specific" do
      it "requires tenure_days for FD" do
        ta = build(:term_account, user: user, parent_account: account,
                   account_type: "fd", tenure_days: nil)
        expect(ta).not_to be_valid
        expect(ta.errors[:tenure_days]).to be_present
      end
    end

    context "PPF specific" do
      it "does not require tenure_days for PPF" do
        ta = build(:term_account, :ppf, user: user, parent_account: account,
                   tenure_days: nil, maturity_amount: 0)
        expect(ta).to be_valid
      end
    end
  end

  describe "before_validation :apply_defaults (on create)" do
    let(:user)    { create(:user) }
    let(:account) { create(:account, user: user) }

    context "FD maturity calculations" do
      it "auto-generates an account_number starting with FD#" do
        ta = create(:term_account, user: user, parent_account: account,
                    account_type: "fd", amount: 50_000, open_date: Date.new(2024, 1, 1),
                    interest_rate: 7.0, tenure_days: 365)
        expect(ta.account_number).to start_with("FD#")
      end

      it "calculates maturity_date as open_date + tenure_days" do
        open_date = Date.new(2024, 1, 1)
        ta = create(:term_account, user: user, parent_account: account,
                    account_type: "fd", amount: 50_000, open_date: open_date,
                    interest_rate: 7.0, tenure_days: 365)
        expect(ta.maturity_date).to eq(open_date + 365.days)
      end

      it "calculates maturity_amount using quarterly compounding formula" do
        ta = create(:term_account, user: user, parent_account: account,
                    account_type: "fd", amount: 100_000, open_date: Date.new(2024, 1, 1),
                    interest_rate: 8.0, tenure_days: 365)
        # P * (1 + r/400)^(4 * years) where years = 365/365
        expected = (100_000 * (1 + 8.0 / 400.0) ** 4).round(2)
        expect(ta.maturity_amount).to eq(expected)
      end

      it "preserves caller-supplied maturity_date when provided" do
        provided_date = Date.new(2025, 6, 15)
        ta = create(:term_account, user: user, parent_account: account,
                    account_type: "fd", amount: 50_000, open_date: Date.new(2024, 1, 1),
                    interest_rate: 7.0, tenure_days: 365, maturity_date: provided_date)
        expect(ta.maturity_date).to eq(provided_date)
      end

      it "preserves caller-supplied maturity_amount when provided" do
        ta = create(:term_account, user: user, parent_account: account,
                    account_type: "fd", amount: 50_000, open_date: Date.new(2024, 1, 1),
                    interest_rate: 7.0, tenure_days: 365, maturity_amount: 55_000)
        expect(ta.maturity_amount).to eq(55_000)
      end
    end

    context "PPF maturity calculations" do
      it "auto-generates an account_number starting with PPF#" do
        ta = create(:term_account, :ppf, user: user, parent_account: account,
                    amount: 5_000, open_date: Date.new(2024, 1, 1),
                    interest_rate: 7.1, maturity_amount: 0)
        expect(ta.account_number).to start_with("PPF#")
      end

      it "sets maturity_date 15 years from open_date using >> operator" do
        open_date = Date.new(2024, 1, 1)
        ta = create(:term_account, :ppf, user: user, parent_account: account,
                    amount: 5_000, open_date: open_date,
                    interest_rate: 7.1, maturity_amount: 0)
        expect(ta.maturity_date).to eq(open_date >> (15 * 12))
      end

      it "preserves caller-supplied maturity_date for PPF" do
        provided_date = Date.new(2039, 6, 1)
        ta = create(:term_account, :ppf, user: user, parent_account: account,
                    amount: 5_000, open_date: Date.new(2024, 1, 1),
                    interest_rate: 7.1, maturity_date: provided_date, maturity_amount: 0)
        expect(ta.maturity_date).to eq(provided_date)
      end
    end

    context "account_number auto-generation" do
      it "does not overwrite a supplied account_number" do
        ta = create(:term_account, user: user, parent_account: account,
                    account_type: "fd", amount: 10_000, open_date: Date.new(2024, 1, 1),
                    interest_rate: 6.5, tenure_days: 180, account_number: "MYFD001")
        expect(ta.account_number).to eq("MYFD001")
      end
    end
  end

  describe "#closed?" do
    it "returns false when is_active is true" do
      ta = build_stubbed(:term_account, is_active: true)
      expect(ta.closed?).to be false
    end

    it "returns true when is_active is false" do
      ta = build_stubbed(:term_account, is_active: false)
      expect(ta.closed?).to be true
    end
  end

  describe "#close!" do
    let(:user)    { create(:user) }
    let(:account) { create(:account, user: user) }
    let(:ta) do
      create(:term_account, user: user, parent_account: account,
             amount: 50_000, balance: 50_000, open_date: Date.new(2024, 1, 1),
             interest_rate: 7.0, tenure_days: 365)
    end

    it "marks the term account as closed" do
      ta.close!(closed_date: Date.today, closed_amount: 53_500)
      expect(ta.reload.is_active).to be false
    end

    it "sets closed_date and closed_amount" do
      ta.close!(closed_date: Date.today, closed_amount: 53_500)
      ta.reload
      expect(ta.closed_date).to eq(Date.today)
      expect(ta.closed_amount).to eq(53_500)
    end

    it "sets balance to 0 on close" do
      ta.close!(closed_date: Date.today, closed_amount: 53_500)
      expect(ta.reload.balance).to eq(0)
    end

    it "raises TermAccount::Error if already closed" do
      ta.close!(closed_date: Date.today, closed_amount: 53_500)
      expect {
        ta.close!(closed_date: Date.today + 1, closed_amount: 53_600)
      }.to raise_error(TermAccount::Error, /already closed/)
    end
  end
end
