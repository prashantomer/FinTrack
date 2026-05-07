require "rails_helper"

RSpec.describe Reports::HoldingSnapshotService, type: :service do
  let(:user)             { create(:user) }
  let(:instrument)       { create(:instrument, last_price: 150.0) }
  let(:user_instrument)  { create(:user_instrument, user: user, instrument: instrument) }
  let(:platform_account) { create(:platform_account, user: user) }

  before do
    create(:investment,
           user: user,
           user_instrument: user_instrument,
           platform_account: platform_account,
           investment_type: "stock",
           trade_type: "buy",
           quantity: 10,
           price: 100,
           amount_invested: 1_000)
  end

  describe "#call" do
    it "writes one snapshot row per active holding for the given date" do
      expect {
        described_class.new(user, date: Date.new(2026, 5, 7)).call
      }.to change(HoldingSnapshot, :count).by(1)
    end

    it "captures the cached holding stats and the live market price" do
      described_class.new(user, date: Date.new(2026, 5, 7)).call
      snap = HoldingSnapshot.last

      expect(snap.user_id).to eq(user.id)
      expect(snap.snapshot_date).to eq(Date.new(2026, 5, 7))
      expect(snap.platform_account_id).to eq(platform_account.id)
      expect(snap.user_instrument_id).to eq(user_instrument.id)
      expect(snap.market_price).to eq(150)
      expect(snap.total_units).to eq(10)
      expect(snap.total_invested).to eq(1_000)
      expect(snap.current_value).to eq(1_500)  # 10 * 150
      expect(snap.unrealized_gain).to eq(500)
    end

    it "is idempotent: re-running the same date upserts (count stays the same)" do
      described_class.new(user, date: Date.new(2026, 5, 7)).call
      expect {
        described_class.new(user, date: Date.new(2026, 5, 7)).call
      }.not_to change(HoldingSnapshot, :count)
    end

    it "updates the existing row in place when the price changes the same day" do
      described_class.new(user, date: Date.new(2026, 5, 7)).call
      first = HoldingSnapshot.last

      instrument.update_columns(last_price: 200.0)
      described_class.new(user, date: Date.new(2026, 5, 7)).call

      reloaded = HoldingSnapshot.find(first.id)
      expect(reloaded.market_price).to eq(200)
      expect(reloaded.current_value).to eq(2_000) # 10 units × 200
      expect(reloaded.unrealized_gain).to eq(1_000)
    end

    it "preserves created_at on overwrite but bumps updated_at" do
      described_class.new(user, date: Date.new(2026, 5, 7)).call
      original = HoldingSnapshot.last

      # Backdate so an unchanged created_at after re-run is provable.
      backdated = 1.hour.ago
      original.update_columns(created_at: backdated, updated_at: backdated)

      instrument.update_columns(last_price: 250.0)
      described_class.new(user, date: Date.new(2026, 5, 7)).call

      reloaded = HoldingSnapshot.find(original.id)
      expect(reloaded.created_at).to be_within(1.second).of(backdated)
      expect(reloaded.updated_at).to be > reloaded.created_at
    end

    it "creates separate rows for separate dates" do
      described_class.new(user, date: Date.new(2026, 5, 6)).call
      expect {
        described_class.new(user, date: Date.new(2026, 5, 7)).call
      }.to change(HoldingSnapshot, :count).by(1)
    end

    it "returns the number of rows written" do
      expect(described_class.new(user, date: Date.new(2026, 5, 7)).call).to eq(1)
    end
  end

  describe ".snapshot_all!" do
    it "iterates over every user" do
      other = create(:user)
      other_inst = create(:instrument, last_price: 50)
      other_ui   = create(:user_instrument, user: other, instrument: other_inst)
      other_pa   = create(:platform_account, user: other)
      create(:investment, user: other, user_instrument: other_ui, platform_account: other_pa,
             investment_type: "stock", trade_type: "buy", quantity: 5, price: 40, amount_invested: 200)

      expect {
        described_class.snapshot_all!(date: Date.new(2026, 5, 7))
      }.to change(HoldingSnapshot, :count).by(2)
    end
  end
end
