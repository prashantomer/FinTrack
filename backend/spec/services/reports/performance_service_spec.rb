require "rails_helper"

RSpec.describe Reports::PerformanceService, type: :service do
  let(:user)            { create(:user) }
  let(:other_user)      { create(:user) }
  let(:instrument)      { create(:instrument) }
  let(:user_instrument) { create(:user_instrument, user: user, instrument: instrument) }
  let(:platform_a)      { create(:platform_account, user: user, nickname: "Coin") }
  let(:platform_b)      { create(:platform_account, user: user, nickname: "Kite") }

  # Holding has a unique (user_instrument_id, platform_account_id) constraint —
  # cache one per (ui, platform) pair across a test and write multiple snapshot
  # rows against it.
  def holding_for(platform:, ui: user_instrument, snap_user: user)
    @holdings ||= {}
    key = [ snap_user.id, ui.id, platform.id ]
    @holdings[key] ||= Folio.create!(
      user:             snap_user,
      user_instrument:  ui,
      platform_account: platform,
      folio_number:     "F-#{key.join('-')}",
      total_units:      100,
      avg_buy_price:    10,
      total_invested:   1,
      current_value:    1,
      unrealized_gain:  0,
      realized_gain:    0
    )
  end

  def make_snapshot(date:, value:, platform: platform_a, unrealized: 0, realized: 0, snap_user: user, ui: user_instrument)
    holding = holding_for(platform: platform, ui: ui, snap_user: snap_user)
    HoldingSnapshot.create!(
      user:               snap_user,
      holding:            holding,
      platform_account:   platform,
      user_instrument:    ui,
      snapshot_date:      date,
      market_price:       50,
      current_value:      value,
      unrealized_gain:    unrealized,
      realized_gain:      realized,
      total_units:        100,
      avg_buy_price:      10,
      total_invested:     value - unrealized
    )
  end

  describe "#call" do
    it "returns net_worth_series with one entry per snapshot_date in window" do
      make_snapshot(date: 3.days.ago.to_date, value: 1_000)
      make_snapshot(date: 2.days.ago.to_date, value: 1_100)
      make_snapshot(date: 1.day.ago.to_date,  value: 1_050)

      result = described_class.new(user, days: 7).call

      expect(result[:net_worth_series].map { |r| r[:value] }).to eq([ 1_000.0, 1_100.0, 1_050.0 ])
      expect(result[:net_worth_series].first[:date]).to eq(3.days.ago.to_date.iso8601)
    end

    it "sums across platforms for each day in net_worth_series" do
      make_snapshot(date: 1.day.ago.to_date, value: 1_000, platform: platform_a)
      make_snapshot(date: 1.day.ago.to_date, value: 500,   platform: platform_b)

      result = described_class.new(user, days: 7).call

      expect(result[:net_worth_series].size).to eq(1)
      expect(result[:net_worth_series].first[:value]).to eq(1_500.0)
    end

    it "pivots per_platform_series with platform nicknames as keys" do
      make_snapshot(date: 1.day.ago.to_date, value: 1_000, platform: platform_a)
      make_snapshot(date: 1.day.ago.to_date, value: 500,   platform: platform_b)

      result = described_class.new(user, days: 7).call
      row = result[:per_platform_series].first

      expect(row[:date]).to eq(1.day.ago.to_date.iso8601)
      expect(row["Coin"]).to eq(1_000.0)
      expect(row["Kite"]).to eq(500.0)
    end

    it "isolates by user — never reads other users' snapshots" do
      other_inst = create(:instrument)
      other_ui   = create(:user_instrument, user: other_user, instrument: other_inst)
      other_pa   = create(:platform_account, user: other_user)
      make_snapshot(date: 1.day.ago.to_date, value: 999_999, platform: other_pa, snap_user: other_user, ui: other_ui)

      make_snapshot(date: 1.day.ago.to_date, value: 100)

      result = described_class.new(user, days: 7).call

      expect(result[:net_worth_series].first[:value]).to eq(100.0)
    end

    it "computes totals from the latest snapshot date in the window" do
      make_snapshot(date: 5.days.ago.to_date, value: 800,  unrealized: 100)
      make_snapshot(date: 1.day.ago.to_date,  value: 1_500, unrealized: 350, realized: 50)

      result = described_class.new(user, days: 30).call

      expect(result[:totals][:current_value]).to eq(1_500.0)
      expect(result[:totals][:unrealized_gain]).to eq(350.0)
    end

    it "rolls realized_gain over the last 30 days into totals" do
      make_snapshot(date: 1.day.ago.to_date,  value: 1_000, realized: 200)
      make_snapshot(date: 5.days.ago.to_date, value: 1_000, realized: 300)

      result = described_class.new(user, days: 90).call

      expect(result[:totals][:realized_30d]).to eq(500.0)
    end

    it "clamps days argument to [1, 365]" do
      expect(described_class.new(user, days: 0).call[:days]).to eq(1)
      expect(described_class.new(user, days: 9999).call[:days]).to eq(365)
    end

    it "returns empty series and zero totals when there are no snapshots" do
      result = described_class.new(user, days: 30).call

      expect(result[:net_worth_series]).to eq([])
      expect(result[:per_platform_series]).to eq([])
      expect(result[:totals]).to eq(current_value: 0.0, unrealized_gain: 0.0, realized_30d: 0.0)
    end

    it "excludes snapshots older than the requested window" do
      make_snapshot(date: 60.days.ago.to_date, value: 9_999)
      make_snapshot(date: 1.day.ago.to_date,   value: 100)

      result = described_class.new(user, days: 30).call

      expect(result[:net_worth_series].size).to eq(1)
      expect(result[:net_worth_series].first[:value]).to eq(100.0)
    end
  end
end
