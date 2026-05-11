require "rails_helper"

RSpec.describe Imports::InvestmentFormatAdapters do
  describe ".for_headers" do
    it "selects Zerodha when the Coin/Kite signature is present" do
      headers = %i[symbol isin trade_date exchange segment series trade_type quantity price trade_id order_id]
      expect(described_class.for_headers(headers)).to eq(Imports::InvestmentFormatAdapters::Zerodha)
    end

    it "is case-insensitive and accepts string headers" do
      headers = [ "Symbol", "ISIN", "Trade_Date", "Segment", "quantity", "price" ]
      expect(described_class.for_headers(headers)).to eq(Imports::InvestmentFormatAdapters::Zerodha)
    end

    it "selects Default for the normalized internal format" do
      headers = %i[trade_type investment_type name amount_invested purchase_date quantity units price]
      expect(described_class.for_headers(headers)).to eq(Imports::InvestmentFormatAdapters::Default)
    end

    it "selects Default when only some Coin headers are present" do
      headers = %i[symbol isin trade_date]
      expect(described_class.for_headers(headers)).to eq(Imports::InvestmentFormatAdapters::Default)
    end

    it "tolerates nil headers" do
      headers = [ :symbol, :isin, :trade_date, :segment, nil ]
      expect(described_class.for_headers(headers)).to eq(Imports::InvestmentFormatAdapters::Zerodha)
    end
  end

  describe Imports::InvestmentFormatAdapters::Default do
    it "passes the row through unchanged" do
      row = { name: "Foo", amount_invested: "100" }
      expect(described_class.transform(row)).to eq(row)
    end
  end

  describe Imports::InvestmentFormatAdapters::Zerodha do
    let(:mf_row) do
      {
        symbol:               "SBI BANKING & FINANCIAL SERVICES FUND - DIRECT PLAN",
        isin:                 "INF200KA1507",
        trade_date:           "2023-08-14",
        exchange:             "BSE",
        segment:              "MF",
        series:               nil,
        trade_type:           "buy",
        auction:              "FALSE",
        quantity:             "163.584000",
        price:                "30.563800",
        trade_id:             "799259193",
        order_id:              "799259193",
        order_execution_time: "2023-08-14T00:00:00"
      }
    end

    it "maps a mutual fund row to the normalized shape" do
      out = described_class.transform(mf_row)

      expect(out[:investment_type]).to eq("mutual_fund")
      expect(out[:name]).to eq("SBI BANKING & FINANCIAL SERVICES FUND - DIRECT PLAN")
      expect(out[:ticker_symbol]).to be_nil
      expect(out[:isin]).to eq("INF200KA1507")
      expect(out[:trade_type]).to eq("buy")
      expect(out[:purchase_date]).to eq("2023-08-14")
      expect(out[:exchange]).to eq("BSE")
      expect(out[:units]).to be_within(1e-6).of(163.584)
      expect(out[:quantity]).to be_nil
      expect(out[:price]).to be_within(1e-6).of(30.5638)
      expect(out[:order_id]).to eq("799259193")
      expect(out[:trade_id]).to eq("799259193")
      expect(out[:platform_name]).to eq("Coin by Zerodha")
    end

    it "computes amount_invested as quantity × price, rounded to 2dp" do
      out = described_class.transform(mf_row)
      # 163.584 * 30.5638 ≈ 4999.7480...
      expect(out[:amount_invested]).to eq(4999.75)
    end

    it "maps an EQ (stock) row, putting symbol on both name and ticker_symbol and using quantity" do
      eq_row = mf_row.merge(symbol: "RELIANCE", isin: "INE002A01018", segment: "EQ", quantity: "10", price: "2500")
      out    = described_class.transform(eq_row)

      expect(out[:investment_type]).to eq("stock")
      expect(out[:name]).to eq("RELIANCE")
      expect(out[:ticker_symbol]).to eq("RELIANCE")
      expect(out[:quantity]).to eq(10.0)
      expect(out[:units]).to be_nil
      expect(out[:amount_invested]).to eq(25_000.00)
    end

    it "routes EQ rows to Kite and MF rows to Coin" do
      eq_out = described_class.transform(mf_row.merge(segment: "EQ", quantity: "1", price: "100"))
      mf_out = described_class.transform(mf_row)

      expect(eq_out[:platform_name]).to eq("Kite by Zerodha")
      expect(mf_out[:platform_name]).to eq("Coin by Zerodha")
    end

    it "raises on an unknown segment" do
      bad = mf_row.merge(segment: "FUT")
      expect { described_class.transform(bad) }.to raise_error(/segment "FUT" is not supported/)
    end

    it "leaves amount_invested nil when quantity or price is blank" do
      partial = mf_row.merge(quantity: "", price: "")
      out     = described_class.transform(partial)
      expect(out[:amount_invested]).to be_nil
    end

    it "trims and lowercases trade_type" do
      out = described_class.transform(mf_row.merge(trade_type: "  SELL "))
      expect(out[:trade_type]).to eq("sell")
    end

    it "is segment-case-insensitive" do
      out = described_class.transform(mf_row.merge(segment: "mf"))
      expect(out[:investment_type]).to eq("mutual_fund")
    end
  end
end
