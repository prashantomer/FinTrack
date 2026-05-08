# == Schema Information
#
# Table name: user_assistant_settings
#
#  id               :bigint           not null, primary key
#  api_key          :text
#  base_url         :string
#  daily_limit      :integer          default(100), not null
#  last_test_error  :text
#  last_test_status :string
#  last_tested_at   :datetime
#  model            :string
#  provider         :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_user_assistant_settings_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe UserAssistantSetting, type: :model do
  let(:user) { create(:user) }
  subject(:setting) { user.create_assistant_setting!(daily_limit: 100) }

  describe "validations" do
    it "rejects unknown providers" do
      setting.provider = "claude-rb"
      expect(setting).not_to be_valid
    end

    it "allows nil provider (unconfigured fallback)" do
      setting.provider = nil
      expect(setting).to be_valid
    end

    it "requires daily_limit > 0" do
      setting.daily_limit = 0
      expect(setting).not_to be_valid
    end
  end

  describe "#effective_*" do
    it "falls back to ollama when provider is nil" do
      setting.update!(provider: nil)
      expect(setting.effective_provider).to eq("ollama")
      expect(setting.effective_model).to eq("gemma4:e4b")
      expect(setting.effective_base_url).to eq("http://localhost:11434")
    end

    it "uses provider defaults when configured but model/base_url unset" do
      setting.update!(provider: "anthropic", model: nil, base_url: nil)
      expect(setting.effective_model).to eq("claude-sonnet-4-6")
      expect(setting.effective_base_url).to eq("https://api.anthropic.com")
    end

    it "honours explicit overrides" do
      setting.update!(provider: "openai", model: "gpt-5", base_url: "https://proxy.example.com")
      expect(setting.effective_model).to eq("gpt-5")
      expect(setting.effective_base_url).to eq("https://proxy.example.com")
    end
  end

  describe "api_key encryption" do
    it "stores ciphertext, returns plaintext from the model" do
      setting.update!(api_key: "sk-secret-abcd1234")

      # Round-trips through the model decryptor
      expect(setting.reload.api_key).to eq("sk-secret-abcd1234")

      # Raw column is ciphertext, NOT plaintext
      raw = ActiveRecord::Base.connection
        .execute("SELECT api_key FROM user_assistant_settings WHERE id = #{setting.id}")
        .first["api_key"]
      expect(raw).not_to include("sk-secret-abcd1234")
      expect(raw).to be_present
    end

    it "exposes only a masked tail to callers" do
      setting.update!(api_key: "sk-secret-abcd1234")
      expect(setting.api_key_tail).to eq("…1234")
    end
  end

  describe "#requires_api_key?" do
    it "is true for hosted providers" do
      setting.update!(provider: "anthropic")
      expect(setting.requires_api_key?).to be true
      setting.update!(provider: "openai")
      expect(setting.requires_api_key?).to be true
    end

    it "is false for ollama" do
      setting.update!(provider: "ollama")
      expect(setting.requires_api_key?).to be false
    end
  end
end
