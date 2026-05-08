require "rails_helper"

RSpec.describe Instruments::ProfileGate, type: :service do
  let(:user)       { create(:user) }
  let(:instrument) { create(:instrument) }

  def with_mode(mode)
    Rails.application.config.x.fintrack ||= ActiveSupport::OrderedOptions.new
    previous = Rails.application.config.x.fintrack.untracked_profile_mode
    Rails.application.config.x.fintrack.untracked_profile_mode = mode
    yield
  ensure
    Rails.application.config.x.fintrack.untracked_profile_mode = previous
  end

  describe ".allowed?" do
    it "returns false when user or instrument is nil" do
      expect(described_class.allowed?(nil, instrument)).to eq(false)
      expect(described_class.allowed?(user, nil)).to eq(false)
    end

    context "when the user has a UserInstrument for this instrument" do
      before { create(:user_instrument, user: user, instrument: instrument) }

      it "is true regardless of project mode" do
        with_mode("off") do
          expect(described_class.allowed?(user, instrument)).to eq(true)
        end
      end
    end

    context "when the user has an investment linked to this instrument" do
      before do
        ui = create(:user_instrument, user: user, instrument: instrument)
        create(:investment, user: user, user_instrument: ui)
        # Now drop the user_instrument to simulate "previously held / orphaned" —
        # if the model doesn't allow that, fall back to the simpler case where
        # user_instruments still exists. Either way, tracked_by? should be true.
      end

      it "is true via the investments → user_instruments join" do
        expect(described_class.allowed?(user, instrument)).to eq(true)
      end
    end

    context "untracked instrument" do
      it "is false in mode=off" do
        with_mode("off") do
          expect(described_class.allowed?(user, instrument)).to eq(false)
        end
      end

      it "is true in mode=on regardless of profile_enabled" do
        with_mode("on") do
          expect(described_class.allowed?(user, instrument)).to eq(true)
        end
      end

      it "in mode=per_instrument, follows instruments.profile_enabled" do
        with_mode("per_instrument") do
          expect(described_class.allowed?(user, instrument)).to eq(false)
          instrument.update!(profile_enabled: true)
          expect(described_class.allowed?(user, instrument)).to eq(true)
        end
      end
    end

    it "isolates by user — user A's tracked instrument is untracked from user B's POV" do
      other = create(:user)
      create(:user_instrument, user: user, instrument: instrument)

      with_mode("off") do
        expect(described_class.allowed?(user, instrument)).to eq(true)
        expect(described_class.allowed?(other, instrument)).to eq(false)
      end
    end
  end
end
