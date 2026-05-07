require "rails_helper"

# These specs codify the most important invariant: every tool is constructed
# with a single User and must NEVER return data belonging to a different user,
# even if the LLM-supplied args reference cross-tenant ids.
RSpec.describe "Assistants::Tools user-isolation", type: :model do
  let(:alice) { create(:user, email: "alice@example.com") }
  let(:bob)   { create(:user, email: "bob@example.com") }
  let(:bank)  { create(:bank) }

  before do
    @alice_account = create(:account, user: alice, bank: bank, nickname: "Alice Savings")
    @bob_account   = create(:account, user: bob,   bank: bank, nickname: "Bob Savings")

    create(:transaction, user: alice, transaction_type: "credit", amount: 1500.00, description: "Alice salary")
    create(:transaction, user: bob,   transaction_type: "credit", amount: 9999.00, description: "Bob salary")
  end

  describe Assistants::Tools::QueryAccounts do
    it "returns only the constructing user's accounts" do
      result = described_class.new(alice).call({})
      nicknames = result[:accounts].map { |a| a[:nickname] }
      expect(nicknames).to include("Alice Savings")
      expect(nicknames).not_to include("Bob Savings")
    end
  end

  describe Assistants::Tools::QueryTransactions do
    it "returns only the constructing user's transactions" do
      result = described_class.new(alice).call({})
      descriptions = result[:items].map { |t| t[:description] }
      expect(descriptions).to include("Alice salary")
      expect(descriptions).not_to include("Bob salary")
    end

    it "ignores any user_id-shaped filter the LLM might smuggle in args" do
      # Args don't include user_id at all — this asserts the schema is closed and
      # tools always derive scope from the injected User.
      expect { described_class.new(alice).call(user_id: bob.id) }.not_to raise_error
      result = described_class.new(alice).call(user_id: bob.id)
      expect(result[:items].map { |t| t[:description] }).not_to include("Bob salary")
    end
  end

  describe Assistants::Tools::LookupInstruments do
    before do
      Instrument.create!(name: "HDFC Bank Ltd", ticker_symbol: "HDFCBANK", isin: "INE040A01034", investment_type: "stock", exchange: "NSE")
      Instrument.create!(name: "State Bank of India", ticker_symbol: "SBIN", isin: "INE062A01020", investment_type: "stock", exchange: "NSE")
      Instrument.create!(name: "HDFC Top 100 Fund - Direct Growth", ticker_symbol: nil, investment_type: "mutual_fund", fund_house: "HDFC AMC")
    end

    it "searches the global catalogue by ticker symbol" do
      result = described_class.new(alice).call(symbol: "HDFCBANK")
      expect(result[:count]).to eq(1)
      expect(result[:instruments].first[:name]).to eq("HDFC Bank Ltd")
    end

    it "errors when no query term is provided" do
      result = described_class.new(alice).call({})
      expect(result[:error]).to eq("missing_query")
    end

    it "treats fund name passed in `symbol` as a name match for MF instruments without a ticker" do
      result = described_class.new(alice).call(symbol: "HDFC Top 100", type: "mutual_fund")
      expect(result[:count]).to eq(1)
      expect(result[:instruments].first[:name]).to eq("HDFC Top 100 Fund - Direct Growth")
    end

    it "surfaces the MF name as the effective ticker for callers" do
      result = described_class.new(alice).call(name: "HDFC Top 100", type: "mutual_fund")
      expect(result[:instruments].first[:ticker_symbol]).to eq("HDFC Top 100 Fund - Direct Growth")
    end
  end
end
