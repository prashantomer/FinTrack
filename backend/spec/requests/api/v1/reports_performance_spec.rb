require "rails_helper"

RSpec.describe "Api::V1::Reports#performance", type: :request do
  let(:user) { create(:user) }

  describe "GET /api/v1/reports/performance" do
    it "returns 401 without an auth header" do
      get "/api/v1/reports/performance"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the canonical payload shape with the right keys" do
      get "/api/v1/reports/performance", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body).fetch("data")
      expect(data.keys).to include("net_worth_series", "per_platform_series", "totals", "days")
      expect(data["totals"].keys).to include("current_value", "unrealized_gain", "realized_30d")
      expect(data["days"]).to eq(Reports::PerformanceService::DEFAULT_DAYS)
    end

    it "honours the days query param and clamps to MAX_DAYS" do
      get "/api/v1/reports/performance", params: { days: 9999 }, headers: auth_headers(user)
      data = JSON.parse(response.body).fetch("data")
      expect(data["days"]).to eq(Reports::PerformanceService::MAX_DAYS)
    end

    it "treats days=0 as 1 (lower clamp)" do
      get "/api/v1/reports/performance", params: { days: 0 }, headers: auth_headers(user)
      data = JSON.parse(response.body).fetch("data")
      expect(data["days"]).to eq(1)
    end
  end
end
