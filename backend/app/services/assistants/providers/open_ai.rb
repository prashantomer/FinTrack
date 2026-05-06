require "openai"
require "json"

module Assistants
  module Providers
    class OpenAi < Provider
      MAX_TOKENS = 2048

      def ping
        require_api_key!
        client = build_client
        measure_latency do
          client.chat(parameters: {
            model: setting.effective_model,
            messages: [ { role: "user", content: PING_PROMPT } ],
            max_tokens: PING_MAX_TOKENS
          })
        end
      rescue ::Faraday::UnauthorizedError, ::OpenAI::Error => e
        translate(e)
      rescue ::Faraday::ConnectionFailed => e
        raise Errors::ProviderUnreachable.new(e.message, provider: "openai", code: "unreachable")
      end

      def chat(system:, messages:, tools: [])
        require_api_key!
        client = build_client

        msgs = [ { role: "system", content: system } ] + messages.map { |m| { role: m[:role], content: m[:content].to_s } }
        params = { model: setting.effective_model, messages: msgs, max_tokens: MAX_TOKENS }
        if tools.any?
          params[:tools] = tools.map { |t| openai_tool(t) }
          params[:tool_choice] = "auto"
        end

        response = nil
        ms = measure_latency { response = client.chat(parameters: params) }
        msg = response.dig("choices", 0, "message") || {}

        tool_calls = Array(msg["tool_calls"]).map do |tc|
          fn = tc["function"] || {}
          {
            id: tc["id"],
            name: fn["name"].to_s,
            input: parse_arguments(fn["arguments"])
          }
        end

        {
          text: msg["content"].to_s,
          tool_calls: tool_calls,
          provider: "openai",
          model: setting.effective_model,
          tokens_in:  response.dig("usage", "prompt_tokens"),
          tokens_out: response.dig("usage", "completion_tokens"),
          latency_ms: ms
        }
      rescue ::Faraday::UnauthorizedError, ::OpenAI::Error => e
        translate(e)
      rescue ::Faraday::ConnectionFailed => e
        raise Errors::ProviderUnreachable.new(e.message, provider: "openai", code: "unreachable")
      end

      private

      def build_client
        ::OpenAI::Client.new(access_token: setting.api_key, uri_base: setting.effective_base_url)
      end

      def parse_arguments(raw)
        return {} if raw.blank?
        return raw if raw.is_a?(Hash)
        JSON.parse(raw.to_s)
      rescue JSON::ParserError
        {}
      end

      def openai_tool(definition)
        {
          type: "function",
          function: {
            name: definition[:name],
            description: definition[:description],
            parameters: definition[:input_schema]
          }
        }
      end

      def translate(err)
        msg = err.message.to_s
        case msg
        when /401|unauthorized|invalid api key/i
          raise Errors::AuthenticationError.new(msg, provider: "openai", code: "auth")
        when /429|rate limit/i
          raise Errors::RateLimitError.new(msg, provider: "openai", code: "rate_limit")
        when /connection|timeout|unreachable/i
          raise Errors::ProviderUnreachable.new(msg, provider: "openai", code: "unreachable")
        else
          raise Errors::InvalidRequest.new(msg, provider: "openai", code: "invalid")
        end
      end
    end
  end
end
