require "anthropic"

module Assistants
  module Providers
    class Anthropic < Provider
      MAX_TOKENS = 2048

      def ping
        require_api_key!
        client = build_client
        measure_latency do
          client.messages.create(
            model: setting.effective_model,
            max_tokens: PING_MAX_TOKENS,
            messages: [ { role: "user", content: PING_PROMPT } ]
          )
        end
      rescue ::Anthropic::Errors::AuthenticationError => e
        raise Errors::AuthenticationError.new(e.message, provider: "anthropic", code: "auth")
      rescue ::Anthropic::Errors::RateLimitError => e
        raise Errors::RateLimitError.new(e.message, provider: "anthropic", code: "rate_limit")
      rescue ::Anthropic::Errors::APIConnectionError, ::Faraday::ConnectionFailed => e
        raise Errors::ProviderUnreachable.new(e.message, provider: "anthropic", code: "unreachable")
      rescue ::Anthropic::Errors::Error => e
        raise Errors::InvalidRequest.new(e.message, provider: "anthropic", code: "invalid")
      end

      # Returns:
      #   { text:, tool_calls: [{id, name, input}], provider:, model:, tokens_in:, tokens_out:, latency_ms: }
      def chat(system:, messages:, tools: [])
        require_api_key!
        client = build_client

        params = {
          model: setting.effective_model,
          max_tokens: MAX_TOKENS,
          system: system,
          messages: messages.map { |m| anthropic_message(m) }
        }
        params[:tools] = tools.map { |t| anthropic_tool(t) } if tools.any?

        response = nil
        ms = measure_latency { response = client.messages.create(**params) }

        text_blocks = []
        tool_calls = []
        Array(response.content).each do |block|
          case block.type
          when :text         then text_blocks << block.text
          when :tool_use     then tool_calls << { id: block.id, name: block.name.to_s, input: block.input.to_h }
          end
        end

        {
          text: text_blocks.join("\n"),
          tool_calls: tool_calls,
          provider: "anthropic",
          model: setting.effective_model,
          tokens_in:  response.usage&.input_tokens,
          tokens_out: response.usage&.output_tokens,
          latency_ms: ms
        }
      rescue ::Anthropic::Errors::AuthenticationError => e
        raise Errors::AuthenticationError.new(e.message, provider: "anthropic", code: "auth")
      rescue ::Anthropic::Errors::RateLimitError => e
        raise Errors::RateLimitError.new(e.message, provider: "anthropic", code: "rate_limit")
      rescue ::Anthropic::Errors::APIConnectionError, ::Faraday::ConnectionFailed => e
        raise Errors::ProviderUnreachable.new(e.message, provider: "anthropic", code: "unreachable")
      rescue ::Anthropic::Errors::Error => e
        raise Errors::InvalidRequest.new(e.message, provider: "anthropic", code: "invalid")
      end

      private

      def build_client
        ::Anthropic::Client.new(api_key: setting.api_key, base_url: setting.effective_base_url)
      end

      def anthropic_message(m)
        # Anthropic accepts plain { role:, content: "string" } OR content blocks
        { role: m[:role], content: m[:content].to_s }
      end

      def anthropic_tool(definition)
        {
          name: definition[:name],
          description: definition[:description],
          input_schema: definition[:input_schema]
        }
      end
    end
  end
end
