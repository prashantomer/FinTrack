require "rails_helper"

RSpec.describe "Api::V1::Instruments profile endpoints", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:instrument) { create(:instrument, last_price: 150) }

  def with_mode(mode)
    Rails.application.config.x.fintrack ||= ActiveSupport::OrderedOptions.new
    previous = Rails.application.config.x.fintrack.untracked_profile_mode
    Rails.application.config.x.fintrack.untracked_profile_mode = mode
    yield
  ensure
    Rails.application.config.x.fintrack.untracked_profile_mode = previous
  end

  describe "auth" do
    it "returns 401 without an auth header on each endpoint" do
      [ "position", "lots", "transactions", "price-history" ].each do |path|
        get "/api/v1/instruments/#{instrument.id}/#{path}"
        expect(response).to have_http_status(:unauthorized), "expected 401 for #{path}"
      end
    end
  end

  describe "gate behaviour" do
    context "when the user is tracking the instrument" do
      before { create(:user_instrument, user: user, instrument: instrument) }

      it "returns 200 for position regardless of project mode" do
        with_mode("off") do
          get "/api/v1/instruments/#{instrument.id}/position", headers: auth_headers(user)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "when the instrument is untracked" do
      it "returns 404 in mode=off (does not leak existence)" do
        with_mode("off") do
          get "/api/v1/instruments/#{instrument.id}/position", headers: auth_headers(user)
          expect(response).to have_http_status(:not_found)
        end
      end

      it "returns 200 in mode=on" do
        with_mode("on") do
          get "/api/v1/instruments/#{instrument.id}/position", headers: auth_headers(user)
          expect(response).to have_http_status(:ok)
        end
      end

      it "respects profile_enabled in mode=per_instrument" do
        with_mode("per_instrument") do
          get "/api/v1/instruments/#{instrument.id}/position", headers: auth_headers(user)
          expect(response).to have_http_status(:not_found)

          instrument.update!(profile_enabled: true)
          get "/api/v1/instruments/#{instrument.id}/position", headers: auth_headers(user)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    it "isolates by user — A's tracked instrument is 404 for B in mode=off" do
      create(:user_instrument, user: user, instrument: instrument)
      with_mode("off") do
        get "/api/v1/instruments/#{instrument.id}/position", headers: auth_headers(other_user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /position" do
    before { create(:user_instrument, user: user, instrument: instrument) }

    it "returns an EMPTY_POSITION shape when the user holds no lots" do
      get "/api/v1/instruments/#{instrument.id}/position", headers: auth_headers(user)
      data = JSON.parse(response.body).fetch("data")
      expect(data["instrument_id"]).to eq(instrument.id)
      expect(data["is_closed"]).to eq(true)
      expect(data["lots"]).to eq([])
    end
  end

  describe "GET /transactions" do
    before do
      create(:user_instrument, user: user, instrument: instrument)
      create(:bank, name: "HDFC Bank", short_name: "HDFC")
    end

    it "returns only this user's transactions for this instrument" do
      mine  = create(:transaction, user: user,       instrument_id: instrument.id, date: 1.day.ago.to_date)
      other = create(:transaction, user: other_user, instrument_id: instrument.id, date: 1.day.ago.to_date)

      get "/api/v1/instruments/#{instrument.id}/transactions", headers: auth_headers(user)
      ids = JSON.parse(response.body).fetch("data").map { |r| r["id"] }
      expect(ids).to include(mine.id)
      expect(ids).not_to include(other.id)
    end
  end

  describe "GET /price-history" do
    before { create(:user_instrument, user: user, instrument: instrument) }

    it "returns rows since the windowed cutoff, oldest-first" do
      InstrumentPriceHistory.create!(instrument_id: instrument.id, price_date: 100.days.ago.to_date, price: 95)
      InstrumentPriceHistory.create!(instrument_id: instrument.id, price_date: 5.days.ago.to_date,   price: 110)

      get "/api/v1/instruments/#{instrument.id}/price-history", params: { days: 30 }, headers: auth_headers(user)
      rows = JSON.parse(response.body).fetch("data")
      expect(rows.size).to eq(1)
      expect(rows.first.keys).to include("date", "price")
    end
  end
end
