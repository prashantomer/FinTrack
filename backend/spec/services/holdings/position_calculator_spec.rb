require "rails_helper"

RSpec.describe Holdings::PositionCalculator do
  let(:user)       { create(:user) }
  let(:instrument) { Instrument.create!(name: "Test Stock", ticker_symbol: "TEST", isin: "INE111A01010", investment_type: "stock") }
  let(:user_inst)  { Instruments::TrackService.new(user, instrument).track }

  def buy(qty:, price:, on:)
    create(:investment, user: user, user_instrument: user_inst,
           name: instrument.name, investment_type: "stock", trade_type: "buy",
           amount_invested: qty * price, quantity: qty, price: price,
           purchase_date: on)
  end

  def sell(qty:, price:, on:)
    create(:investment, :sell, user: user, user_instrument: user_inst,
           name: instrument.name, investment_type: "stock",
           amount_invested: qty * price, quantity: qty, price: price,
           purchase_date: on)
  end

  describe "FIFO walk with two-buy / one-partial-sell" do
    # Buy A: 10 @ 100 (day -10), Buy B: 10 @ 200 (day -5), Sell: 5 @ 250 (day -1)
    # FIFO consumes Buy A → cost_basis_held = 5×100 + 10×200 = 2,500
    # FIFO realized = 1,250 − 5×100 = 750
    # WAVG avg = 150 → cost_basis_held = 15×150 = 2,250; realized = 1,250 − 5×150 = 500
    # current_price = 300 → current_value = 15×300 = 4,500
    let!(:lots) do
      [
        buy(qty: 10, price: 100, on: Date.current - 10.days),
        buy(qty: 10, price: 200, on: Date.current - 5.days),
        sell(qty: 5, price: 250, on: Date.current - 1.day)
      ]
    end

    let(:stats) { described_class.call(lots, current_price: 300, investment_type: "stock") }

    it "computes FIFO cost_basis_held by consuming earliest buys" do
      expect(stats[:cost_basis_held]).to eq(2_500)
      expect(stats[:total_invested]).to eq(2_500) # alias matching Holding column
    end

    it "computes FIFO realized_gain on the consumed quantity" do
      expect(stats[:realized_gain]).to eq(750)
    end

    it "computes unrealized_gain against the live current_price" do
      expect(stats[:unrealized_gain]).to eq(2_000) # 4,500 − 2,500
    end

    it "exposes WAVG as a comparison block" do
      expect(stats[:wavg][:cost_basis_held]).to eq(2_250)
      expect(stats[:wavg][:realized_gain]).to eq(500)
      expect(stats[:wavg][:unrealized_gain]).to eq(2_250) # 4,500 − 2,250
    end

    it "satisfies the canonical identity under both methods" do
      identity = stats[:current_value] - stats[:net_cash_deployed]
      expect(identity).to eq(2_750)
      expect(stats[:unrealized_gain] + stats[:realized_gain]).to eq(2_750)
      expect(stats[:wavg][:unrealized_gain] + stats[:wavg][:realized_gain]).to eq(2_750)
    end

    it "reports avg_buy_price as the FIFO held-lots average" do
      # cost_basis_held / held_qty = 2,500 / 15 ≈ 166.67
      expect(stats[:avg_buy_price]).to be_within(0.01).of(166.67)
    end
  end

  describe "fully closed position" do
    let!(:lots) do
      [
        buy(qty: 10, price: 100, on: Date.current - 10.days),
        sell(qty: 10, price: 130, on: Date.current - 1.day)
      ]
    end

    let(:stats) { described_class.call(lots, current_price: 200, investment_type: "stock") }

    it "marks closed and zeroes the held cost basis and current_value" do
      expect(stats[:is_closed]).to be true
      expect(stats[:cost_basis_held]).to eq(0)
      expect(stats[:current_value]).to eq(0)
      expect(stats[:total_units]).to eq(0)
    end

    it "reports the same realized gain under FIFO and WAVG when there is one buy lot" do
      expect(stats[:realized_gain]).to eq(300)
      expect(stats[:wavg][:realized_gain]).to eq(300)
    end
  end

  describe "single buy, no sells" do
    let!(:lots) { [ buy(qty: 10, price: 100, on: Date.current - 5.days) ] }
    let(:stats) { described_class.call(lots, current_price: 110, investment_type: "stock") }

    it "FIFO and WAVG are identical when no sells exist" do
      expect(stats[:cost_basis_held]).to eq(stats[:wavg][:cost_basis_held])
      expect(stats[:realized_gain]).to    eq(0)
      expect(stats[:unrealized_gain]).to  eq(100) # 10×110 − 10×100
    end
  end
end
