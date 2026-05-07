require "rails_helper"

RSpec.describe Imports::ProcessTermAccountRowService, type: :service do
  let(:user)    { create(:user) }
  let(:bank)    { create(:bank) }
  let(:account) { create(:account, user: user, bank: bank, nickname: "Savings Main", balance: 200_000) }
  let(:batch)   { create(:import_batch, :term_accounts, user: user) }

  def build_fd_row(overrides = {})
    {
      account_type:             "fd",
      parent_account_nickname:  "Savings Main",
      account_number:           nil,
      amount:                   "50000",
      open_date:                "2024-01-01",
      interest_rate:            "7.0",
      tenure_days:              "365",
      maturity_date:            nil,
      maturity_amount:          nil,
      balance:                  nil
    }.merge(overrides)
  end

  def build_ppf_row(overrides = {})
    {
      account_type:             "ppf",
      parent_account_nickname:  "Savings Main",
      account_number:           nil,
      amount:                   "5000",
      open_date:                "2024-01-01",
      interest_rate:            "7.1",
      tenure_days:              nil,
      maturity_date:            nil,
      maturity_amount:          nil,
      balance:                  nil
    }.merge(overrides)
  end

  def call_fd_service(idx: 0, **overrides)
    account  # ensure parent account exists
    described_class.new(batch, build_fd_row(overrides), idx).call
  end

  def call_ppf_service(idx: 0, **overrides)
    account  # ensure parent account exists
    described_class.new(batch, build_ppf_row(overrides), idx).call
  end

  describe "#call — FD" do
    it "creates a TermAccount record" do
      expect { call_fd_service }.to change(TermAccount, :count).by(1)
    end

    it "sets account_type to fd" do
      call_fd_service
      expect(TermAccount.last.account_type).to eq("fd")
    end

    it "sets the correct amount" do
      call_fd_service
      expect(TermAccount.last.amount).to eq(50_000.0)
    end

    it "sets the correct open_date" do
      call_fd_service
      expect(TermAccount.last.open_date).to eq(Date.new(2024, 1, 1))
    end

    it "sets the correct interest_rate" do
      call_fd_service
      expect(TermAccount.last.interest_rate).to eq(7.0)
    end

    it "sets tenure_days" do
      call_fd_service
      expect(TermAccount.last.tenure_days).to eq(365)
    end

    it "auto-calculates maturity_date as open_date + tenure_days" do
      call_fd_service
      expect(TermAccount.last.maturity_date).to eq(Date.new(2024, 1, 1) + 365.days)
    end

    it "auto-calculates maturity_amount using quarterly compounding" do
      call_fd_service
      ta = TermAccount.last
      expected = (50_000 * (1 + 7.0 / 400.0) ** 4).round(2)
      expect(ta.maturity_amount).to eq(expected)
    end

    it "respects a caller-supplied maturity_date" do
      call_fd_service(maturity_date: "2025-06-30")
      expect(TermAccount.last.maturity_date).to eq(Date.new(2025, 6, 30))
    end

    it "respects a caller-supplied maturity_amount" do
      call_fd_service(maturity_amount: "55000")
      expect(TermAccount.last.maturity_amount).to eq(55_000.0)
    end

    it "defaults balance to amount when not supplied" do
      call_fd_service
      expect(TermAccount.last.balance).to eq(50_000.0)
    end

    it "uses supplied balance when provided" do
      call_fd_service(balance: "45000")
      expect(TermAccount.last.balance).to eq(45_000.0)
    end

    it "links the term account to the parent savings account" do
      call_fd_service
      expect(TermAccount.last.parent_account).to eq(account)
    end

    it "accepts DD/MM/YYYY open_date format" do
      call_fd_service(open_date: "01/01/2024")
      expect(TermAccount.last.open_date).to eq(Date.new(2024, 1, 1))
    end
  end

  describe "#call — PPF" do
    it "creates a PPF TermAccount" do
      expect { call_ppf_service }.to change(TermAccount, :count).by(1)
    end

    it "sets account_type to ppf" do
      call_ppf_service
      expect(TermAccount.last.account_type).to eq("ppf")
    end

    it "auto-calculates maturity_date as 15 years from open_date" do
      call_ppf_service
      expected = Date.new(2024, 1, 1) >> (15 * 12)
      expect(TermAccount.last.maturity_date).to eq(expected)
    end

    it "defaults maturity_amount to 0 when not supplied" do
      call_ppf_service
      expect(TermAccount.last.maturity_amount).to eq(0)
    end

    it "respects a caller-supplied maturity_amount for PPF" do
      call_ppf_service(maturity_amount: "200000")
      expect(TermAccount.last.maturity_amount).to eq(200_000.0)
    end
  end

  describe "ImportRecord creation" do
    it "creates an ImportRecord with status :ok" do
      expect { call_fd_service }.to change(ImportRecord, :count).by(1)
    end

    it "sets the import record status to ok" do
      call_fd_service
      expect(ImportRecord.last.status).to eq("ok")
    end

    it "sets the correct row_index" do
      call_fd_service(idx: 2)
      expect(ImportRecord.last.row_index).to eq(2)
    end

    it "sets importable to the created term account" do
      call_fd_service
      expect(ImportRecord.last.importable).to eq(TermAccount.last)
    end

    it "includes account type and parent account nickname in notes" do
      call_fd_service
      expect(ImportRecord.last.notes).to include("Savings Main")
      expect(ImportRecord.last.notes).to include("FD")
    end
  end

  describe "duplicate detection" do
    it "skips when (account_type, account_number) matches an existing FD" do
      call_fd_service(account_number: "FD-001")
      expect {
        call_fd_service(idx: 1, account_number: "FD-001", amount: "999999")
      }.not_to change(TermAccount, :count)
    end

    it "returns DUPLICATE and creates a :skipped ImportRecord referencing the existing FD" do
      first  = call_fd_service(account_number: "FD-001")
      result = call_fd_service(idx: 1, account_number: "FD-001")
      expect(result).to eq(described_class::DUPLICATE)
      ir = ImportRecord.where(status: "skipped").last
      expect(ir.importable).to eq(first)
      expect(ir.notes).to include("Duplicate of TermAccount ##{first.id}").and include("FD #FD-001")
    end

    it "falls back to (parent_account, open_date, amount, account_type) when no number is given" do
      call_fd_service(account_number: nil)
      expect {
        call_fd_service(idx: 1, account_number: nil)
      }.not_to change(TermAccount, :count)
    end
  end

  describe "error cases" do
    it "raises when parent_account_nickname is blank" do
      account  # ensure account exists
      expect {
        described_class.new(batch, build_fd_row(parent_account_nickname: ""), 0).call
      }.to raise_error(/parent_account_nickname is required/)
    end

    it "raises when parent account is not found" do
      account  # ensure account exists — but we pass a different name
      expect {
        described_class.new(batch, build_fd_row(parent_account_nickname: "Unknown Account"), 0).call
      }.to raise_error(/not found/)
    end

    it "raises when amount is zero" do
      expect { call_fd_service(amount: "0") }.to raise_error(/amount must be greater than 0/)
    end

    it "raises when amount is negative" do
      expect { call_fd_service(amount: "-5000") }.to raise_error(/amount must be greater than 0/)
    end

    it "raises when interest_rate is zero or missing" do
      expect { call_fd_service(interest_rate: "0") }.to raise_error(/interest_rate is required/)
    end

    it "raises when tenure_days is missing for FD" do
      expect { call_fd_service(tenure_days: nil) }.to raise_error(/tenure_days is required for FD/)
    end

    it "raises when account_type is invalid" do
      expect {
        described_class.new(batch, build_fd_row(account_type: "nps"), 0).call
      }.to raise_error(/account_type must be 'fd' or 'ppf'/)
    end

    it "raises when open_date is blank" do
      expect { call_fd_service(open_date: "") }.to raise_error(/open_date is required/)
    end

    it "raises when open_date format is unrecognisable" do
      expect { call_fd_service(open_date: "January 1 2024") }.to raise_error(/Invalid open_date/)
    end
  end
end
