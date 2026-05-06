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
end
