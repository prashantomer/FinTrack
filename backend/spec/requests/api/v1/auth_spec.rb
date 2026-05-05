require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  let(:password) { "securepassword1" }
  let(:user)     { create(:user, password: password) }

  describe "POST /api/v1/auth/login" do
    context "with valid credentials" do
      it "returns HTTP 200" do
        post "/api/v1/auth/login", params: { email: user.email, password: password }
        expect(response).to have_http_status(:ok)
      end

      it "returns success: true" do
        post "/api/v1/auth/login", params: { email: user.email, password: password }
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns an access_token" do
        post "/api/v1/auth/login", params: { email: user.email, password: password }
        json = JSON.parse(response.body)
        expect(json.dig("data", "access_token")).to be_present
      end

      it "returns the user object" do
        post "/api/v1/auth/login", params: { email: user.email, password: password }
        json = JSON.parse(response.body)
        expect(json.dig("data", "user", "email")).to eq(user.email)
      end

      it "returns token_type as bearer" do
        post "/api/v1/auth/login", params: { email: user.email, password: password }
        json = JSON.parse(response.body)
        expect(json.dig("data", "token_type")).to eq("bearer")
      end
    end

    context "with a wrong password" do
      it "returns HTTP 401" do
        post "/api/v1/auth/login", params: { email: user.email, password: "wrong_password" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns an error message" do
        post "/api/v1/auth/login", params: { email: user.email, password: "wrong_password" }
        json = JSON.parse(response.body)
        expect(json["error"]).to match(/Invalid email or password/i)
      end

      it "returns success: false" do
        post "/api/v1/auth/login", params: { email: user.email, password: "wrong_password" }
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end
    end

    context "with an unknown email" do
      it "returns HTTP 401" do
        post "/api/v1/auth/login", params: { email: "nobody@example.com", password: password }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns an error message" do
        post "/api/v1/auth/login", params: { email: "nobody@example.com", password: password }
        json = JSON.parse(response.body)
        expect(json["error"]).to match(/Invalid email or password/i)
      end
    end
  end

  describe "GET /api/v1/auth/me" do
    context "with a valid Bearer token" do
      it "returns HTTP 200" do
        get "/api/v1/auth/me", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it "returns the authenticated user's data" do
        get "/api/v1/auth/me", headers: auth_headers(user)
        json = JSON.parse(response.body)
        expect(json.dig("data", "email")).to eq(user.email)
      end

      it "returns success: true" do
        get "/api/v1/auth/me", headers: auth_headers(user)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end

    context "without a token" do
      it "returns HTTP 401" do
        get "/api/v1/auth/me"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a malformed token" do
      it "returns HTTP 401" do
        get "/api/v1/auth/me", headers: { "Authorization" => "Bearer not_a_real_token" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a token for a non-existent user" do
      it "returns HTTP 401" do
        token = JsonWebToken.encode(user_id: 999_999_999)
        get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
