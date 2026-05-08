require "rails_helper"

RSpec.describe Investment, "holding refresh callback" do
  before { Current.skip_holding_refresh = nil }

  let(:user)       { create(:user) }
  let(:instrument) { Instrument.create!(name: "ABC Corp", ticker_symbol: "ABC", isin: "INE222A01010", investment_type: "stock") }
  let(:user_inst)  { Instruments::TrackService.new(user, instrument).track }
  let(:platform)   { create(:platform) }
  let(:account)    { create(:platform_account, user: user, platform: platform) }

  def build_investment
    Investment.new(
      user: user, user_instrument: user_inst, platform_account: account,
      name: instrument.name, investment_type: "stock", trade_type: "buy",
      amount_invested: 1_000, quantity: 10, price: 100,
      purchase_date: Date.current - 1.day
    )
  end

  describe "#enqueue_holding_refresh" do
    it "enqueues Holdings::RefreshJob with the right (user_id, ui_id, pa_id)" do
      inv = build_investment
      expect(Holdings::RefreshJob).to receive(:perform_later).with(user.id, user_inst.id, account.id)
      inv.send(:enqueue_holding_refresh)
    end

    it "does not enqueue when Current.skip_holding_refresh is set (bulk-import path)" do
      Current.skip_holding_refresh = true
      inv = build_investment
      expect(Holdings::RefreshJob).not_to receive(:perform_later)
      inv.send(:enqueue_holding_refresh)
    ensure
      Current.skip_holding_refresh = nil
    end

    it "does not enqueue when user_instrument_id is missing" do
      inv = build_investment
      inv.user_instrument = nil
      expect(Holdings::RefreshJob).not_to receive(:perform_later)
      inv.send(:enqueue_holding_refresh)
    end

    it "does not enqueue when platform_account_id is missing" do
      inv = build_investment
      inv.platform_account = nil
      expect(Holdings::RefreshJob).not_to receive(:perform_later)
      inv.send(:enqueue_holding_refresh)
    end
  end

  describe Holdings::RefreshJob do
    it "dispatches to RefreshService for a single (ui, pa) pair" do
      expect(Holdings::RefreshService).to receive(:new).with(user, 42, 7).and_return(double(call: nil))
      described_class.new.perform(user.id, 42, 7)
    end

    it "dispatches a full-user sweep when only user_id is given" do
      expect(Holdings::RefreshService).to receive(:refresh_all_for).with(user)
      described_class.new.perform(user.id)
    end

    it "dispatches refresh_for_user_instrument when only user_id and ui_id are given" do
      expect(Holdings::RefreshService).to receive(:refresh_for_user_instrument).with(user, 42)
      described_class.new.perform(user.id, 42)
    end

    it "is a no-op when user_id is unknown" do
      expect(Holdings::RefreshService).not_to receive(:new)
      expect(Holdings::RefreshService).not_to receive(:refresh_all_for)
      described_class.new.perform(999_999_999)
    end
  end
end
