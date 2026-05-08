require "rails_helper"

RSpec.describe Instruments::PriceBackfillService, type: :service do
  describe ".nse_for_date" do
    let(:tracked) { create(:instrument, ticker_symbol: "RELIANCE", investment_type: "stock") }
    let(:other)   { create(:instrument, ticker_symbol: "INFY",     investment_type: "stock") }
    let(:date)    { Date.new(2026, 5, 7) } # Thursday — explicitly a weekday

    let(:bhavcopy_csv) do
      <<~CSV
        SYMBOL,SERIES,DATE1,PREV_CLOSE,OPEN_PRICE,HIGH_PRICE,LOW_PRICE,LAST_PRICE,CLOSE_PRICE
        RELIANCE,EQ,07-May-2026,2700.0,2710.0,2750.0,2705.0,2745.0,2740.50
        INFY,EQ,07-May-2026,1500.0,1510.0,1525.0,1498.0,1520.0,1518.75
        TATA,BE,07-May-2026,100.0,101.0,103.0,99.0,102.0,101.50
      CSV
    end

    it "upserts price history rows for tracked stocks only" do
      allow(Instruments::HttpFetcher).to receive(:get).and_return(bhavcopy_csv)

      result = described_class.nse_for_date(date, [ tracked.id ])

      expect(result.inserted).to eq(1)
      expect(result.unmatched).to eq(1) # INFY exists but isn't in tracked set
      expect(result.skipped_non_trading).to be(false)

      row = InstrumentPriceHistory.find_by(instrument_id: tracked.id, price_date: date)
      expect(row.price).to eq(2740.50)
      expect(row.source).to eq("nse_bhavcopy")
    end

    it "is idempotent on a same-day re-run" do
      allow(Instruments::HttpFetcher).to receive(:get).and_return(bhavcopy_csv)
      described_class.nse_for_date(date, [ tracked.id ])
      expect {
        described_class.nse_for_date(date, [ tracked.id ])
      }.not_to change(InstrumentPriceHistory, :count)
    end

    it "treats HTTP 404 as a non-trading day without raising" do
      allow(Instruments::HttpFetcher).to receive(:get)
        .and_raise(Instruments::HttpFetcher::NotFound.new("HTTP 404"))

      result = described_class.nse_for_date(date, [ tracked.id ])
      expect(result.skipped_non_trading).to be(true)
      expect(result.inserted).to eq(0)
      expect(InstrumentPriceHistory.count).to eq(0)
    end

    it "skips weekends without making any HTTP request" do
      saturday = Date.new(2026, 5, 9)
      expect(Instruments::HttpFetcher).not_to receive(:get)

      result = described_class.nse_for_date(saturday, [ tracked.id ])
      expect(result.skipped_non_trading).to be(true)
    end

    it "is a no-op when the tracked-id set is empty" do
      expect(Instruments::HttpFetcher).not_to receive(:get)
      result = described_class.nse_for_date(date, [])
      expect(result.inserted).to eq(0)
    end

    it "ignores non-EQ series rows (e.g. BE/SM)" do
      allow(Instruments::HttpFetcher).to receive(:get).and_return(bhavcopy_csv)
      described_class.nse_for_date(date, [ tracked.id, other.id ])
      tickers_inserted = InstrumentPriceHistory.where(price_date: date)
                                              .joins(:instrument)
                                              .pluck("instruments.ticker_symbol")
      expect(tickers_inserted).to contain_exactly("RELIANCE", "INFY")
      # TATA was BE-series, so it never entered the upsert
    end
  end

  describe ".amfi_for_range" do
    let(:tracked_isin) { "INF209K01ZA8" }
    let!(:tracked) do
      create(:instrument, :mutual_fund, isin: tracked_isin, name: "SBI Tracked Fund")
    end
    let(:from_date) { Date.new(2026, 4, 1) }
    let(:to_date)   { Date.new(2026, 4, 3) }

    # Real portal column order: Scheme Code; Scheme Name; ISIN Growth;
    # ISIN Reinvestment; NAV; Repurchase; Sale Price; Date.
    let(:nav_history_body) do
      <<~TXT
        Scheme Code;Scheme Name;ISIN Div Payout/ISIN Growth;ISIN Div Reinvestment;Net Asset Value;Repurchase Price;Sale Price;Date
        SBI Mutual Fund Ltd.;
        Open Ended Schemes(Equity Scheme - Other)
        100001;SBI Tracked Fund - Direct Plan - Growth;#{tracked_isin};-;120.45;;;01-Apr-2026
        100001;SBI Tracked Fund - Direct Plan - Growth;#{tracked_isin};-;121.10;;;02-Apr-2026
        100001;SBI Tracked Fund - Direct Plan - Growth;#{tracked_isin};-;N.A.;;;03-Apr-2026
        200002;Other Untracked Fund - Direct Plan - Growth;INFOTHERSCHEME;-;55.00;;;01-Apr-2026
      TXT
    end

    it "upserts NAV rows for tracked ISINs across the date range, skipping invalid NAVs" do
      allow(Instruments::HttpFetcher).to receive(:get).and_return(nav_history_body)

      result = described_class.amfi_for_range(from_date, to_date, [ tracked_isin ])

      expect(result.inserted).to eq(2)
      expect(result.unmatched).to eq(1) # the other untracked fund
      expect(result.invalid).to eq(1)   # the N.A. row

      rows = InstrumentPriceHistory.where(instrument_id: tracked.id).order(:price_date)
      expect(rows.map(&:price_date)).to eq([ Date.new(2026, 4, 1), Date.new(2026, 4, 2) ])
      expect(rows.map(&:price)).to eq([ 120.45, 121.10 ])
      expect(rows.map(&:source).uniq).to eq([ "amfi_navhistory" ])
    end

    it "is a no-op when the tracked-ISIN set is empty" do
      expect(Instruments::HttpFetcher).not_to receive(:get)
      result = described_class.amfi_for_range(from_date, to_date, [])
      expect(result.inserted).to eq(0)
    end

    it "is idempotent on a re-run" do
      allow(Instruments::HttpFetcher).to receive(:get).and_return(nav_history_body)
      described_class.amfi_for_range(from_date, to_date, [ tracked_isin ])
      expect {
        described_class.amfi_for_range(from_date, to_date, [ tracked_isin ])
      }.not_to change(InstrumentPriceHistory, :count)
    end
  end
end
