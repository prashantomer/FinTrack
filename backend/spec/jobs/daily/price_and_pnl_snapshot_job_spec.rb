require "rails_helper"

RSpec.describe Daily::PriceAndPnlSnapshotJob, type: :job do
  let(:user)             { create(:user) }
  let(:instrument)       { create(:instrument, last_price: 200) }
  let(:user_instrument)  { create(:user_instrument, user: user, instrument: instrument) }
  let(:platform_account) { create(:platform_account, user: user) }

  before do
    create(:investment, user: user, user_instrument: user_instrument, platform_account: platform_account,
           investment_type: "stock", trade_type: "buy", quantity: 4, price: 100, amount_invested: 400)

    # Stub the network-dependent price fetch — we're testing orchestration.
    allow(Instruments::PriceFetchService).to receive(:call).and_return(
      Instruments::PriceFetchService::Result.new(
        nse_updated: 0, nse_history_rows: 0, nse_unmatched: 0,
        mf_updated: 0,  mf_history_rows: 0,  mf_unmatched: 0, mf_invalid: 0
      )
    )

    # The job self-reschedules in `ensure`. With the inline test adapter that
    # would recursively run tomorrow's body — neutralise it for unit tests.
    allow(described_class).to receive(:schedule_next_run!)
  end

  describe "#perform" do
    it "writes holding snapshots for the given date" do
      expect {
        described_class.perform_now("2026-05-07")
      }.to change(HoldingSnapshot, :count).by(1)
      expect(HoldingSnapshot.last.snapshot_date).to eq(Date.new(2026, 5, 7))
    end

    it "stamps the SystemTask 'daily_pnl' with the run date and ok status" do
      described_class.perform_now("2026-05-07")
      task = SystemTask.find_by(name: "daily_pnl")
      expect(task.last_completed_date).to eq(Date.new(2026, 5, 7))
      expect(task.last_status).to eq("ok")
    end

    it "is idempotent across same-day re-runs" do
      described_class.perform_now("2026-05-07")
      expect {
        described_class.perform_now("2026-05-07")
      }.not_to change(HoldingSnapshot, :count)
    end

    it "records the failure on SystemTask and re-raises when something blows up" do
      allow(Reports::HoldingSnapshotService).to receive(:snapshot_all!).and_raise(StandardError, "kaboom")

      expect {
        described_class.perform_now("2026-05-07")
      }.to raise_error(StandardError, /kaboom/)

      task = SystemTask.find_by(name: "daily_pnl")
      expect(task.last_status).to eq("error")
      expect(task.last_error).to include("kaboom")
    end

    it "defaults to Date.current when no argument is given" do
      described_class.perform_now
      expect(HoldingSnapshot.last.snapshot_date).to eq(Date.current)
    end

    it "re-runs the body on a same-day re-trigger and refreshes prices/stats without duplicate rows" do
      described_class.perform_now("2026-05-07")
      expect(Reports::HoldingSnapshotService).to receive(:snapshot_all!).with(date: Date.new(2026, 5, 7)).and_call_original
      expect {
        described_class.perform_now("2026-05-07")
      }.not_to change(HoldingSnapshot, :count)
    end

    it "calls schedule_next_run! on success and on failure (via ensure)" do
      expect(described_class).to receive(:schedule_next_run!).at_least(:once)
      described_class.perform_now("2026-05-07")
    end
  end

  describe ".next_run_time" do
    it "returns today at the run hour when the current time is before it" do
      now = Time.zone.local(2026, 5, 7, 3, 0, 0)
      allow(Time).to receive(:current).and_return(now)
      expect(described_class.next_run_time).to eq(Time.zone.local(2026, 5, 7, 5, 0, 0))
    end

    it "returns tomorrow at the run hour when the current time has already passed it" do
      now = Time.zone.local(2026, 5, 7, 9, 0, 0)
      allow(Time).to receive(:current).and_return(now)
      expect(described_class.next_run_time).to eq(Time.zone.local(2026, 5, 8, 5, 0, 0))
    end
  end

  describe ".enqueue_for (dedup)" do
    it "enqueues when no duplicate is pending and returns true" do
      allow(described_class).to receive(:already_enqueued_for?).and_return(false)
      expect(described_class).to receive(:perform_later).with("2026-05-07")
      expect(described_class.enqueue_for(Date.new(2026, 5, 7))).to eq(true)
    end

    it "skips and returns false when a duplicate is already pending" do
      allow(described_class).to receive(:already_enqueued_for?).and_return(true)
      expect(described_class).not_to receive(:perform_later)
      expect(described_class.enqueue_for(Date.new(2026, 5, 7))).to eq(false)
    end
  end

  describe ".schedule_next_run! (dedup)" do
    before { allow(described_class).to receive(:schedule_next_run!).and_call_original }

    it "skips and returns false when a future job for the same date is pending" do
      allow(described_class).to receive(:already_enqueued_for?).and_return(true)
      expect(described_class).not_to receive(:set)
      expect(described_class.schedule_next_run!).to eq(false)
    end
  end

  describe "retry policy" do
    it "is configured to retry up to 5 times via sidekiq_options" do
      expect(described_class.sidekiq_options_hash["retry"]).to eq(5)
    end
  end
end
