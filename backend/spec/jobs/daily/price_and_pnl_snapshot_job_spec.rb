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
  end
end
