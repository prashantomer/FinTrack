module Assistants
  # Abstract base. Providers implement #ping (sanity check, returns latency_ms)
  # and #chat (streaming completion).
  class Provider
    PING_PROMPT = "ping".freeze
    PING_MAX_TOKENS = 4

    attr_reader :setting

    def self.for(setting)
      case setting.effective_provider
      when "anthropic" then Providers::Anthropic.new(setting)
      when "openai"    then Providers::OpenAi.new(setting)
      when "ollama"    then Providers::Ollama.new(setting)
      else
        raise Errors::NotConfigured.new("unknown provider: #{setting.effective_provider.inspect}")
      end
    end

    def initialize(setting)
      @setting = setting
    end

    # Issue a tiny test call. Returns latency_ms on success, raises a subclass
    # of Errors::ProviderError otherwise.
    def ping
      raise NotImplementedError
    end

    # Streaming chat. Implemented in task #7 (conversation orchestrator).
    def chat(messages:, tools: [], &on_chunk)
      raise NotImplementedError
    end

    protected

    def measure_latency
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
    end

    def require_api_key!
      return if setting.api_key.present?
      raise Errors::AuthenticationError.new(
        "API key is required for provider #{setting.effective_provider}",
        provider: setting.effective_provider,
        code: "missing_api_key"
      )
    end
  end
end
