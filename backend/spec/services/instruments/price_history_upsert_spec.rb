require "rails_helper"

# Migrated from price_fetch_service_spec.rb when the same-day upsert helper was
# extracted into its own module. Behaviour expectations are unchanged.
RSpec.describe Instruments::PriceHistoryUpsert do
  let(:instrument) { create(:instrument) }

  def row(price, instrument_id: instrument.id, date: Date.new(2026, 5, 7), source: "nse_bhavcopy")
    { instrument_id: instrument_id, price_date: date, price: price, source: source }
  end

  it "inserts a new row on the first run for that date" do
    expect { described_class.call([ row(100.0) ]) }.to change(InstrumentPriceHistory, :count).by(1)
  end

  it "updates the existing row on a same-day re-run with a new price" do
    described_class.call([ row(100.0) ])
    expect { described_class.call([ row(110.0) ]) }.not_to change(InstrumentPriceHistory, :count)

    expect(InstrumentPriceHistory.last.price).to eq(110.0)
  end

  it "preserves created_at on the same-day re-run while bumping updated_at" do
    described_class.call([ row(100.0) ])
    first = InstrumentPriceHistory.last

    backdated = 1.hour.ago
    first.update_columns(created_at: backdated, updated_at: backdated)

    described_class.call([ row(105.0) ])
    reloaded = InstrumentPriceHistory.find(first.id)
    expect(reloaded.created_at).to be_within(1.second).of(backdated)
    expect(reloaded.updated_at).to be > reloaded.created_at
  end

  it "is a no-op for an empty array" do
    expect { described_class.call([]) }.not_to change(InstrumentPriceHistory, :count)
    expect(described_class.call([])).to eq(0)
  end
end
