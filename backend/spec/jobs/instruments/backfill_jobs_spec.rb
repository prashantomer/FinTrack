require "rails_helper"

RSpec.describe "Instruments backfill jobs", type: :job do
  describe Instruments::BackfillNsePricesJob do
    it "delegates to PriceBackfillService.nse_for_date with parsed args" do
      expect(Instruments::PriceBackfillService).to receive(:nse_for_date)
        .with(Date.new(2026, 5, 7), [ 1, 2, 3 ])
      described_class.perform_now("2026-05-07", [ 1, 2, 3 ])
    end
  end

  describe Instruments::BackfillAmfiNavsJob do
    it "delegates to PriceBackfillService.amfi_for_range with parsed args" do
      expect(Instruments::PriceBackfillService).to receive(:amfi_for_range)
        .with(Date.new(2026, 4, 1), Date.new(2026, 4, 30), [ "INF209K01ZA8" ])
      described_class.perform_now("2026-04-01", "2026-04-30", [ "INF209K01ZA8" ])
    end
  end
end
