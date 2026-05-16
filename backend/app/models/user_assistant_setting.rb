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
class UserAssistantSetting < ApplicationRecord
  # PROVIDERS = %w[anthropic openai ollama].freeze
  PROVIDERS = %w[openai ollama].freeze

  DEFAULT_MODEL_BY_PROVIDER = {
    # "anthropic" => "claude-sonnet-4-6",
    "openai"    => "gpt-4o-mini",
    "ollama"    => "gemma4:e4b"
  }.freeze

  DEFAULT_BASE_URL_BY_PROVIDER = {
    # "anthropic" => "https://api.anthropic.com",
    "openai"    => "https://api.openai.com/v1",
    "ollama"    => "http://localhost:11434"
  }.freeze

  belongs_to :user

  encrypts :api_key

  validates :provider, inclusion: { in: PROVIDERS }, allow_nil: true
  validates :daily_limit, numericality: { greater_than: 0, only_integer: true }

  # Returns the provider that should actually be used: the configured one, or
  # ollama as a no-config fallback.
  def effective_provider
    provider.presence || "ollama"
  end

  def effective_model
    model.presence || DEFAULT_MODEL_BY_PROVIDER[effective_provider]
  end

  def effective_base_url
    base_url.presence || DEFAULT_BASE_URL_BY_PROVIDER[effective_provider]
  end

  def configured?
    provider.present?
  end

  # True when the user picked a provider that needs an API key.
  def requires_api_key?
    %w[anthropic openai].include?(effective_provider)
  end

  def api_key_present?
    api_key.present?
  end

  # Last 4 chars of the key, for masked display. Never return the full value.
  def api_key_tail
    return nil unless api_key_present?
    "…#{api_key.to_s[-4..]}"
  end

  def record_test_result(status, latency_ms: nil, error: nil)
    update!(
      last_tested_at: Time.current,
      last_test_status: status.to_s,
      last_test_error: error.to_s.presence
    )
  end
end
