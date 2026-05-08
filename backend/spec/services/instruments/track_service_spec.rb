require "rails_helper"

RSpec.describe Instruments::TrackService, type: :service do
  let(:user)       { create(:user) }
  let(:instrument) { create(:instrument) }

  # Stub the coordinator job so the suite doesn't actually fan out 250+ NSE
  # fetches via the :inline test queue adapter (it would reach the network).
  before do
    allow(Instruments::FirstTimeBackfillJob).to receive(:perform_later)
  end

  describe "#track" do
    it "creates a UserInstrument the first time" do
      expect {
        described_class.new(user, instrument).track
      }.to change { user.user_instruments.count }.by(1)
    end

    it "is idempotent — re-tracking the same instrument is a no-op" do
      described_class.new(user, instrument).track
      expect {
        described_class.new(user, instrument).track
      }.not_to change { user.user_instruments.count }
    end

    it "enqueues a FirstTimeBackfillJob on the very first track" do
      described_class.new(user, instrument).track
      expect(Instruments::FirstTimeBackfillJob).to have_received(:perform_later).with(instrument.id)
    end

    it "does NOT enqueue a backfill on a re-track" do
      described_class.new(user, instrument).track
      described_class.new(user, instrument).track
      expect(Instruments::FirstTimeBackfillJob).to have_received(:perform_later).once
    end

    it "does NOT enqueue a backfill when called with backfill: false (bulk path)" do
      described_class.new(user, instrument).track(backfill: false)
      expect(Instruments::FirstTimeBackfillJob).not_to have_received(:perform_later)
    end

    it "still creates the UserInstrument when backfill is opted out" do
      expect {
        described_class.new(user, instrument).track(backfill: false)
      }.to change { user.user_instruments.count }.by(1)
    end
  end

  describe "#untrack" do
    it "removes the UserInstrument" do
      described_class.new(user, instrument).track
      expect {
        described_class.new(user, instrument).untrack
      }.to change { user.user_instruments.count }.by(-1)
    end
  end
end
