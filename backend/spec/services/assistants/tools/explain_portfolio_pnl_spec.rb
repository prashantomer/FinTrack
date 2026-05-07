require "rails_helper"

RSpec.describe Assistants::Tools::ExplainPortfolioPnl, type: :service do
  let(:user)       { create(:user) }
  let(:instrument) { Instrument.create!(name: "HDFC Bank Ltd", ticker_symbol: "HDFCBANK", isin: "INE040A01034", investment_type: "stock", exchange: "NSE", last_price: 300.00) }
  let(:user_inst)  { Instruments::TrackService.new(user, instrument).track }
  let(:tool)       { described_class.new(user) }

  describe "definition" do
    it "exposes a name and an optional user_instrument_id input" do
      definition = tool.definition
      expect(definition[:name]).to eq("explain_portfolio_pnl")
      expect(definition[:input_schema][:properties][:user_instrument_id][:type]).to eq("integer")
      expect(definition[:input_schema][:properties][:user_instrument_id][:description]).to be_present
    end
  end

  describe "FIFO vs WAVG split when sells exist" do
    # Two buys at different prices then a partial sell:
    #   Buy A: 10 @ 100 (day −10)
    #   Buy B: 10 @ 200 (day −5)
    #   Sell : 5  @ 250 (day −1)  → proceeds 1,250
    #   last_price = 300
    #
    # WAVG: avg = 150  → cost_basis_held = 15 × 150 = 2,250
    #                    unrealized = 15×300 − 2,250 = 2,250
    #                    realized   = 1,250 − 5×150 = 500
    # FIFO: consume 5 from A → cost_basis_held = 5×100 + 10×200 = 2,500
    #                            unrealized = 15×300 − 2,500 = 2,000
    #                            realized   = 5×(250 − 100)   = 750
    # Net cash deployed = (1,000 + 2,000) − 1,250 = 1,750
    # Identity: current_value − net_cash_deployed = 4,500 − 1,750 = 2,750
    #           = WAVG (2,250 + 500) = FIFO (2,000 + 750)
    before do
      create(:investment, user: user, user_instrument: user_inst,
             name: instrument.name, investment_type: "stock", trade_type: "buy",
             amount_invested: 1_000, quantity: 10, price: 100,
             purchase_date: Date.current - 10.days)
      create(:investment, user: user, user_instrument: user_inst,
             name: instrument.name, investment_type: "stock", trade_type: "buy",
             amount_invested: 2_000, quantity: 10, price: 200,
             purchase_date: Date.current - 5.days)
      create(:investment, :sell, user: user, user_instrument: user_inst,
             name: instrument.name, investment_type: "stock",
             amount_invested: 1_250, quantity: 5, price: 250,
             purchase_date: Date.current - 1.day)
    end

    let(:result) { tool.call({}) }
    let(:pos)    { result[:positions].first }

    it "reports the WAVG numbers from PortfolioService" do
      expect(pos[:wavg][:cost_basis_held]).to eq(2_250)
      expect(pos[:wavg][:unrealized_gain]).to eq(2_250)
      expect(pos[:wavg][:realized_gain]).to   eq(500)
    end

    it "computes FIFO cost_basis_held by consuming buys in date order" do
      expect(pos[:fifo][:cost_basis_held]).to eq(2_500)
    end

    it "computes FIFO realized as (sell_price − earliest_buy_price) × consumed_qty" do
      expect(pos[:fifo][:realized_gain]).to eq(750)
    end

    it "computes FIFO unrealized against the live current_price" do
      expect(pos[:fifo][:unrealized_gain]).to eq(2_000)
    end

    it "exposes net_cash_deployed for cash-flow reconciliation" do
      expect(pos[:net_cash_deployed]).to eq(1_750)
    end

    it "satisfies the identity: current_value − net_cash_deployed = WAVG total = FIFO total" do
      identity = pos[:current_value].to_f - pos[:net_cash_deployed].to_f
      expect(identity).to eq(2_750)
      expect(pos[:wavg][:unrealized_gain].to_f + pos[:wavg][:realized_gain].to_f).to eq(2_750)
      expect(pos[:fifo][:unrealized_gain] + pos[:fifo][:realized_gain]).to             eq(2_750)
      expect(pos[:identity_check]).to eq(2_750)
    end

    it "rolls up totals across positions for both methods" do
      totals = result[:totals]
      expect(totals[:current_value]).to eq(4_500)
      expect(totals[:net_cash_deployed]).to eq(1_750)
      expect(totals[:wavg][:total_gain]).to eq(2_750)
      expect(totals[:fifo][:total_gain]).to eq(2_750)
    end

    it "advertises fifo as the in-app method" do
      expect(result[:method_used_in_app]).to eq("fifo")
    end

    it "carries the canonical identity string for the LLM" do
      expect(result[:identity]).to include("current_value")
      expect(result[:identity]).to include("net_cash_deployed")
    end

    it "filters to a single position via user_instrument_id" do
      filtered = tool.call("user_instrument_id" => user_inst.id)
      expect(filtered[:positions].size).to eq(1)
      expect(filtered[:positions].first[:user_instrument_id]).to eq(user_inst.id)
    end

    it "returns an empty positions array for an unknown user_instrument_id" do
      filtered = tool.call("user_instrument_id" => 9_999_999)
      expect(filtered[:positions]).to be_empty
    end
  end

  describe "fully closed position (sold everything)" do
    # 10 @ 100 buy, 10 @ 130 sell → net qty 0; closed.
    before do
      create(:investment, user: user, user_instrument: user_inst,
             name: instrument.name, investment_type: "stock", trade_type: "buy",
             amount_invested: 1_000, quantity: 10, price: 100,
             purchase_date: Date.current - 10.days)
      create(:investment, :sell, user: user, user_instrument: user_inst,
             name: instrument.name, investment_type: "stock",
             amount_invested: 1_300, quantity: 10, price: 130,
             purchase_date: Date.current - 1.day)
    end

    let(:pos) { tool.call({})[:positions].first }

    it "marks the position as closed with zero current_value and zero held cost basis" do
      expect(pos[:is_closed]).to be true
      expect(pos[:current_value]).to eq(0)
      expect(pos[:wavg][:cost_basis_held]).to eq(0)
      expect(pos[:fifo][:cost_basis_held]).to be_within(1e-6).of(0)
    end

    it "still reports the realized gain identical under WAVG and FIFO when there is one buy lot" do
      expect(pos[:wavg][:realized_gain]).to eq(300)
      expect(pos[:fifo][:realized_gain]).to eq(300)
    end
  end
end
