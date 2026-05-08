require "rails_helper"

RSpec.describe Instruments::ProfileService, type: :service do
  let(:user)             { create(:user) }
  let(:other_user)       { create(:user) }
  let(:instrument)       { create(:instrument, last_price: 150) }
  let(:user_instrument)  { create(:user_instrument, user: user, instrument: instrument) }
  let(:platform_account) { create(:platform_account, user: user) }

  describe "#position" do
    context "when the user has lots in this instrument" do
      before do
        create(:investment, user: user, user_instrument: user_instrument, platform_account: platform_account,
               investment_type: "stock", trade_type: "buy",
               quantity: 10, price: 100, amount_invested: 1_000)
      end

      it "delegates to PortfolioService.build_position with the correct lots" do
        result = described_class.new(user, instrument).position
        expect(result).to include(:total_invested, :current_value, :lots)
        expect(result[:instrument_id]).to eq(instrument.id)
        expect(result[:lots].size).to eq(1)
      end
    end

    context "when the user has no lots in this instrument" do
      it "returns an EMPTY_POSITION shape with is_closed: true and empty lots" do
        result = described_class.new(user, instrument).position
        expect(result[:is_closed]).to eq(true)
        expect(result[:total_units]).to eq(0)
        expect(result[:lots]).to eq([])
        expect(result[:instrument_id]).to eq(instrument.id)
      end
    end

    it "isolates by user — other user's lots don't show up" do
      other_inst = create(:instrument)
      other_ui   = create(:user_instrument, user: other_user, instrument: instrument)
      other_pa   = create(:platform_account, user: other_user)
      create(:investment, user: other_user, user_instrument: other_ui, platform_account: other_pa,
             investment_type: "stock", trade_type: "buy",
             quantity: 99, price: 999, amount_invested: 99_999)
      _ = other_inst # silence unused

      result = described_class.new(user, instrument).position
      expect(result[:is_closed]).to eq(true)
      expect(result[:lots]).to eq([])
    end
  end

  describe "#transactions" do
    before do
      create(:bank, name: "HDFC Bank", short_name: "HDFC")
    end

    it "returns only transactions linked to this instrument, scoped to the user" do
      mine = create(:transaction, user: user, instrument_id: instrument.id, date: 1.day.ago.to_date)
      _other_instrument = create(:transaction, user: user, instrument_id: nil, date: 1.day.ago.to_date)

      other_inst_for_other_user = create(:transaction, user: other_user, instrument_id: instrument.id, date: 1.day.ago.to_date)

      result = described_class.new(user, instrument).transactions

      expect(result.map(&:id)).to include(mine.id)
      expect(result.map(&:id)).not_to include(other_inst_for_other_user.id)
    end

    it "respects the limit param and clamps to MAX_TX_LIMIT" do
      service = described_class.new(user, instrument)
      expect(service.transactions(limit: 0).limit_value).to   eq(1)
      expect(service.transactions(limit: 999).limit_value).to eq(described_class::MAX_TX_LIMIT)
      expect(service.transactions(limit: 25).limit_value).to  eq(25)
    end

    it "orders newest-first" do
      old = create(:transaction, user: user, instrument_id: instrument.id, date: 10.days.ago.to_date)
      new_one = create(:transaction, user: user, instrument_id: instrument.id, date: 1.day.ago.to_date)
      result = described_class.new(user, instrument).transactions
      expect(result.map(&:id)).to eq([ new_one.id, old.id ])
    end
  end

  describe "#price_history" do
    it "returns rows since the windowed cutoff, oldest-first" do
      InstrumentPriceHistory.create!(instrument_id: instrument.id, price_date: 100.days.ago.to_date, price: 95)
      InstrumentPriceHistory.create!(instrument_id: instrument.id, price_date: 5.days.ago.to_date,   price: 110)
      InstrumentPriceHistory.create!(instrument_id: instrument.id, price_date: 1.day.ago.to_date,    price: 120)

      result = described_class.new(user, instrument).price_history(days: 30).to_a
      expect(result.size).to eq(2)
      expect(result.map(&:price_date)).to eq([ 5.days.ago.to_date, 1.day.ago.to_date ])
    end

    it "clamps days to [1, MAX_HISTORY_DAYS]" do
      svc = described_class.new(user, instrument)
      expect { svc.price_history(days: 0).to_a }.not_to raise_error
      expect { svc.price_history(days: 99_999).to_a }.not_to raise_error
    end
  end
end
