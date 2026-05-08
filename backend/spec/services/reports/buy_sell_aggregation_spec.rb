require "rails_helper"

# Locks in the most important new behaviour: investments are now trades
# (buy/sell), so holdings = buys minus sells per instrument.
RSpec.describe "Buy/Sell aggregation across reports", type: :service do
  let(:user)       { create(:user) }
  let(:bank)       { create(:bank) }
  let!(:account)   { create(:account, user: user, bank: bank) }
  let(:instrument) { Instrument.create!(name: "HDFC Bank Ltd", ticker_symbol: "HDFCBANK", isin: "INE040A01034", investment_type: "stock", exchange: "NSE") }
  let(:user_inst)  { Instruments::TrackService.new(user, instrument).track }

  # Pattern: bought 10 shares @ ₹700 (₹7,000 invested, current_value ₹8,000 → ₹800/share today).
  # Sold 4 @ ₹800 → ₹3,200 proceeds.
  # Net residual position: 6 shares.
  #
  # Cost basis of held shares  : 6 × 700 = ₹4,200
  # Current value of position  : 6 × 800 = ₹4,800
  # Unrealized gain            : 4,800 − 4,200 = ₹600
  # Realized gain on sells     : 3,200 − (4 × 700) = ₹400
  # Net cash deployed (info)   : 7,000 − 3,200 = ₹3,800
  before do
    create(:investment, user: user, user_instrument: user_inst,
           name: instrument.name, investment_type: "stock", trade_type: "buy",
           amount_invested: 7_000.00, purchase_date: Date.current - 30.days,
           quantity: 10, price: 700.00, current_value: 8_000.00)
    create(:investment, :sell, user: user, user_instrument: user_inst,
           name: instrument.name, investment_type: "stock",
           amount_invested: 3_200.00, purchase_date: Date.current - 5.days,
           quantity: 4,  price: 800.00)
  end

  describe Reports::PortfolioService do
    let(:result) { described_class.new(user).call }
    let(:pos)    { result[:positions].first }

    it "exposes buy_lots and sell_lots counts" do
      expect(pos[:buy_lots]).to  eq(1)
      expect(pos[:sell_lots]).to eq(1)
      expect(pos[:total_lots]).to eq(2)
    end

    it "tracks the residual quantity (buys minus sells)" do
      expect(pos[:total_units]).to eq(6)
    end

    it "computes total_invested as cost basis of CURRENTLY HELD shares" do
      expect(pos[:total_invested]).to eq(4_200.00) # 6 shares × ₹700 cost basis
    end

    it "exposes net_cash_deployed for cash-flow reporting" do
      expect(pos[:net_cash_deployed]).to eq(3_800.00) # 7000 - 3200
    end

    it "scales current_value down to the residual quantity" do
      expect(pos[:current_value]).to eq(4_800.00) # 6 shares × ₹800/share
    end

    it "computes unrealized_gain on the held position only" do
      expect(pos[:unrealized_gain]).to eq(600.00) # 4800 - 4200
    end

    it "computes realized_gain as (sell proceeds - avg cost basis * sold qty)" do
      expect(pos[:realized_gain]).to eq(400.00) # 3200 - 4*700
    end
  end

  describe Reports::DashboardService do
    let(:dash) { described_class.new(user).call }

    it "reports portfolio_value scaled to the residual position" do
      expect(dash[:portfolio_value]).to eq(4_800.00)
    end

    it "reports total_invested as cost basis of held shares" do
      expect(dash[:total_invested]).to eq(4_200.00)
    end
  end

  describe Reports::InvestmentSummaryService do
    let(:summary) { described_class.new(user).call }

    it "summary holdings reflect held cost basis and live value" do
      expect(summary[:total_invested]).to eq(4_200.00)
      expect(summary[:total_current_value]).to eq(4_800.00)
    end
  end
end
