require "rails_helper"

RSpec.describe Instruments::PriceBackfillScheduler do
  # Stub perform_later so the :inline test adapter doesn't actually hit
  # archives.nseindia.com / portal.amfiindia.com 250+ times per spec.
  before do
    allow(Instruments::BackfillNsePricesJob).to receive(:perform_later)
    allow(Instruments::BackfillAmfiNavsJob).to receive(:perform_later)
  end

  describe ".enqueue_for(stock)" do
    let(:stock) { create(:instrument, ticker_symbol: "RELIANCE", investment_type: "stock") }

    it "enqueues one BackfillNsePricesJob per missing weekday in the last 365 days" do
      result = described_class.enqueue_for(stock)
      expect(result[:kind]).to eq(:nse)
      # 365 days has roughly 260 weekdays — accept a sane band so the spec
      # doesn't go red around year-boundary edge cases.
      expect(result[:enqueued]).to be_between(255, 265)
      expect(Instruments::BackfillNsePricesJob).to have_received(:perform_later)
        .with(kind_of(String), [ stock.id ]).exactly(result[:enqueued]).times
    end

    it "skips dates already covered by prior daily fetches" do
      covered = (0..90).map { |i| Date.current - i }.reject { |d| d.saturday? || d.sunday? }.first(60)
      covered.each do |d|
        InstrumentPriceHistory.create!(
          instrument_id: stock.id, price_date: d, price: 100.0, source: "nse_bhavcopy",
        )
      end

      received = []
      allow(Instruments::BackfillNsePricesJob).to receive(:perform_later) do |date_iso, ids|
        received << [ Date.parse(date_iso), ids ]
      end

      result = described_class.enqueue_for(stock)
      expect(result[:already_covered]).to eq(60)

      received_dates = received.map(&:first)
      expect(received_dates & covered).to be_empty
      expect(received.map(&:last).uniq).to eq([ [ stock.id ] ])
    end

    it "returns :missing_ticker when ticker_symbol is blank" do
      stock.update_column(:ticker_symbol, nil)
      expect(described_class.enqueue_for(stock)).to eq(:missing_ticker)
      expect(Instruments::BackfillNsePricesJob).not_to have_received(:perform_later)
    end
  end

  describe ".enqueue_for(mutual_fund)" do
    let(:mf) { create(:instrument, :mutual_fund) }

    it "enqueues 13 chunked AMFI range-jobs covering the year" do
      result = described_class.enqueue_for(mf)
      expect(result[:kind]).to eq(:amfi)
      expect(result[:enqueued]).to eq(13)
      expect(Instruments::BackfillAmfiNavsJob).to have_received(:perform_later)
        .with(kind_of(String), kind_of(String), [ mf.isin ]).exactly(13).times
    end

    it "returns :missing_isin when isin is blank" do
      mf.update_column(:isin, nil)
      expect(described_class.enqueue_for(mf)).to eq(:missing_isin)
      expect(Instruments::BackfillAmfiNavsJob).not_to have_received(:perform_later)
    end
  end
end
