require "faraday"
require "json"

module Assistants
  module Providers
    # Ollama runs locally; no API key. v1 sends a plain text completion (no tool
    # use) — most local models don't support tool calling reliably.
    class Ollama < Provider
      def ping
        client = build_client
        measure_latency do
          response = client.get("/api/tags")
          unless response.success?
            raise Errors::InvalidRequest.new(
              "Ollama returned #{response.status}: #{response.body.to_s[0, 200]}",
              provider: "ollama", code: "http_#{response.status}"
            )
          end
        end
      rescue ::Faraday::ConnectionFailed
        raise Errors::ProviderUnreachable.new(
          "Could not connect to Ollama at #{setting.effective_base_url}. Is it running?",
          provider: "ollama", code: "unreachable"
        )
      end

      def chat(system:, messages:, tools: [])
        client = build_client
        msgs = [ { role: "system", content: system } ] + messages.map { |m| { role: m[:role], content: m[:content].to_s } }

        body = { model: setting.effective_model, messages: msgs, stream: false }
        if tools.any?
          # Ollama's tool calling is opt-in per model — include tool defs but degrade gracefully if the model ignores them.
          body[:tools] = tools.map { |t| { type: "function", function: { name: t[:name], description: t[:description], parameters: t[:input_schema] } } }
        end

        response = nil
        ms = measure_latency { response = client.post("/api/chat", body) }

        unless response.success?
          raise Errors::InvalidRequest.new(
            "Ollama returned #{response.status}: #{response.body.to_s[0, 200]}",
            provider: "ollama", code: "http_#{response.status}"
          )
        end

        msg = response.body.is_a?(Hash) ? response.body["message"] || {} : {}
        tool_calls = Array(msg["tool_calls"]).map do |tc|
          fn = tc["function"] || {}
          { id: tc["id"] || SecureRandom.hex(8), name: fn["name"].to_s, input: parse_args(fn["arguments"]) }
        end

        {
          text: msg["content"].to_s,
          tool_calls: tool_calls,
          provider: "ollama",
          model: setting.effective_model,
          tokens_in:  response.body["prompt_eval_count"],
          tokens_out: response.body["eval_count"],
          latency_ms: ms
        }
      rescue ::Faraday::ConnectionFailed
        raise Errors::ProviderUnreachable.new(
          "Could not connect to Ollama at #{setting.effective_base_url}. Is it running?",
          provider: "ollama", code: "unreachable"
        )
      end

      private

      def parse_args(raw)
        return {} if raw.blank?
        return raw if raw.is_a?(Hash)
        JSON.parse(raw.to_s)
      rescue JSON::ParserError
        {}
      end

      def build_client
        ::Faraday.new(url: setting.effective_base_url) do |f|
          f.request :json
          f.response :json
          f.options.timeout = 120
          f.options.open_timeout = 5
        end
      end
    end
  end
end
