require "rails_helper"

RSpec.describe Investments::Filter, type: :service do
  let(:user)    { create(:user) }
  let(:bank)    { create(:bank) }
  let!(:account) { create(:account, user: user, bank: bank) }

  let!(:tcs_buy) do
    create(:investment, user: user, name: "TCS", investment_type: "stock",
           trade_type: "buy", purchase_date: Date.new(2026, 4, 1),
           amount_invested: 10_000, quantity: 10, price: 1_000,
           order_id: "ORD-TCS-001", trade_id: "TRD-TCS-001")
  end
  let!(:tcs_sell) do
    create(:investment, :sell, user: user, name: "TCS", investment_type: "stock",
           purchase_date: Date.new(2026, 5, 5),
           amount_invested: 4_500, quantity: 4, price: 1_125,
           order_id: "ORD-TCS-002", trade_id: "TRD-TCS-EXEC-A")
  end
  let!(:hdfc_buy) do
    create(:investment, user: user, name: "HDFC Mid Cap", investment_type: "mutual_fund",
           trade_type: "buy", purchase_date: Date.new(2026, 4, 15),
           amount_invested: 5_000, units: 25, price: 200,
           order_id: "ORD-MF-001", trade_id: "TRD-MF-001")
  end

  def call(params = {})
    filter = described_class.new(ActionController::Parameters.new(params).permit!)
    Investments::QueryService.new(user, filter).call
  end

  describe "investment_type" do
    it "filters to a single type" do
      expect(call(investment_type: %w[stock])[:items].pluck(:id)).to match_array([ tcs_buy.id, tcs_sell.id ])
    end
  end

  describe "trade_type" do
    it "filters to buys" do
      expect(call(trade_type: "buy")[:items].pluck(:id)).to match_array([ tcs_buy.id, hdfc_buy.id ])
    end

    it "filters to sells" do
      expect(call(trade_type: "sell")[:items].pluck(:id)).to match_array([ tcs_sell.id ])
    end
  end

  describe "search" do
    it "matches by name (case-insensitive)" do
      expect(call(search: "tcs")[:items].pluck(:id)).to match_array([ tcs_buy.id, tcs_sell.id ])
    end

    it "matches by order_id" do
      expect(call(search: "ORD-MF-001")[:items].pluck(:id)).to eq([ hdfc_buy.id ])
    end

    it "matches by trade_id substring" do
      expect(call(search: "TRD-TCS-EXEC")[:items].pluck(:id)).to eq([ tcs_sell.id ])
    end

    it "matches by transaction_public_id" do
      pub_id = tcs_buy.reload.transaction_public_id
      expect(call(search: pub_id.to_s.first(8))[:items].pluck(:id)).to include(tcs_buy.id)
    end
  end

  describe "date range" do
    it "filters by date_from" do
      expect(call(date_from: "2026-04-15")[:items].pluck(:id)).to match_array([ tcs_sell.id, hdfc_buy.id ])
    end

    it "filters by date_to" do
      expect(call(date_to: "2026-04-15")[:items].pluck(:id)).to match_array([ tcs_buy.id, hdfc_buy.id ])
    end

    it "combines from + to as a closed range" do
      expect(call(date_from: "2026-04-10", date_to: "2026-04-30")[:items].pluck(:id)).to eq([ hdfc_buy.id ])
    end
  end

  describe "combinations" do
    it "applies all filters with AND semantics" do
      result = call(investment_type: %w[stock], trade_type: "sell", search: "TCS", date_from: "2026-05-01")
      expect(result[:items].pluck(:id)).to eq([ tcs_sell.id ])
    end
  end

  describe "FilterBase plumbing" do
    it "normalizes pagination defaults and clamps page_size" do
      filter = described_class.new(ActionController::Parameters.new(page_size: 1_000).permit!)
      expect(filter.page).to eq(1)
      expect(filter.page_size).to eq(::Queries::FilterBase::MAX_PAGE_SIZE)
    end

    it "from_params permits the declared fields directly from controller params" do
      raw = ActionController::Parameters.new(
        investment_type: %w[stock], trade_type: "buy", search: "TCS",
        date_from: "2026-04-01", page: "2", junk: "ignored"
      )
      filter = described_class.from_params(raw)
      expect(filter.investment_type).to eq(%w[stock])
      expect(filter.trade_type).to eq("buy")
      expect(filter.search).to eq("TCS")
      expect(filter.date_from).to eq("2026-04-01")
      expect(filter.page).to eq(2)
      expect(filter.raw[:junk]).to be_nil
    end
  end
end
