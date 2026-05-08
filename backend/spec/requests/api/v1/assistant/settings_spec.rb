require "rails_helper"

RSpec.describe "Api::V1::Assistant::Settings", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/assistant/setting" do
    it "creates a default settings row on first read" do
      expect { get "/api/v1/assistant/setting", headers: headers }.to change { UserAssistantSetting.where(user_id: user.id).count }.from(0).to(1)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "configured")).to be false
      expect(json.dig("data", "effective_provider")).to eq("ollama")
      expect(json.dig("data", "has_api_key")).to be false
    end
  end

  describe "PATCH /api/v1/assistant/setting" do
    it "saves provider/model/base_url and never echoes the api_key" do
      patch "/api/v1/assistant/setting",
            params: { provider: "anthropic", model: "claude-sonnet-4-6", api_key: "sk-ant-secret-1234" }.to_json,
            headers: headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "provider")).to eq("anthropic")
      expect(json.dig("data", "has_api_key")).to be true
      expect(json.dig("data", "api_key_tail")).to eq("…1234")
      expect(response.body).not_to include("sk-ant-secret-1234")
    end

    it "leaves an existing api_key untouched when the field is sent blank" do
      user.create_assistant_setting!(provider: "openai", api_key: "old-key-7777")

      patch "/api/v1/assistant/setting",
            params: { provider: "openai", model: "gpt-4o-mini", api_key: "" }.to_json,
            headers: headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:ok)
      expect(user.assistant_setting.reload.api_key).to eq("old-key-7777")
    end
  end

  describe "POST /api/v1/assistant/setting/test" do
    it "returns ok=true when the provider ping succeeds" do
      stub_provider = double("provider", ping: 42)
      allow(Assistants::Provider).to receive(:for).and_return(stub_provider)

      user.create_assistant_setting!(provider: "ollama")
      post "/api/v1/assistant/setting/test", params: {}.to_json, headers: headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "ok")).to be true
      expect(json.dig("data", "latency_ms")).to eq(42)
    end

    it "returns ok=false with structured error when the provider ping fails" do
      stub_provider = double("provider")
      allow(stub_provider).to receive(:ping)
        .and_raise(Assistants::Errors::ProviderUnreachable.new("can't connect", provider: "ollama", code: "unreachable"))
      allow(Assistants::Provider).to receive(:for).and_return(stub_provider)

      user.create_assistant_setting!(provider: "ollama")
      post "/api/v1/assistant/setting/test", params: {}.to_json, headers: headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "ok")).to be false
      expect(json.dig("data", "code")).to eq("unreachable")
      expect(json.dig("data", "error_class")).to eq("ProviderUnreachable")
    end
  end
end
