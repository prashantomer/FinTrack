module Assistants
  # End-to-end orchestrator for a single chat turn.
  #
  #   result = Conversation.new(user).run!(
  #     content: "What did I spend on groceries last week?",
  #     session_id: "...",
  #     attachment_id: nil,
  #     reference_ids: []
  #   )
  #   result.user_message     # AssistantMessage row (role=user)
  #   result.assistant_message # AssistantMessage row (role=assistant, final answer)
  #   result.tool_messages    # [AssistantMessage rows, role=tool]
  class Conversation
    Result = Struct.new(:user_message, :assistant_message, :tool_messages, keyword_init: true)

    MAX_TOOL_ROUNDTRIPS = 6  # safety cap — prevents the model from looping tools forever

    attr_reader :user, :setting

    def initialize(user)
      @user = user
      @setting = user.assistant_setting || user.create_assistant_setting!
    end

    def run!(content:, session_id:, attachment_id: nil, reference_ids: [])
      attachment = lookup_attachment(attachment_id)
      user_msg = persist_user_message(content, session_id, attachment)

      provider = Provider.for(setting)
      tools = ToolRegistry.all_for(user)
      tool_messages = []

      messages = ContextBuilder.new(user, session_id).build(
        new_user_content: content,
        attachment: attachment,
        references: reference_ids
      )
      system_prompt = SystemPrompt.for(user)

      assistant_text = nil
      provider_meta = {}

      MAX_TOOL_ROUNDTRIPS.times do
        result = provider.chat(
          system: system_prompt,
          messages: messages,
          tools: tools.map(&:definition)
        )
        provider_meta = result.slice(:provider, :model, :tokens_in, :tokens_out, :latency_ms)

        if result[:tool_calls].present?
          # Append assistant turn (the tool_use itself) and execute each tool
          messages << { role: "assistant", content: result[:tool_calls_raw] || result[:text].to_s.presence }
          result[:tool_calls].each do |tc|
            tool = ToolRegistry.find(user, tc[:name])
            tool_result =
              if tool.nil?
                { error: "unknown_tool", name: tc[:name] }
              else
                begin
                  tool.call(tc[:input] || {})
                rescue => e
                  { error: "tool_failed", name: tc[:name], message: e.message }
                end
              end

            tool_messages << AssistantMessage.create!(
              user: user, session_id: session_id,
              role: "tool", tool_name: tc[:name],
              tool_arguments: tc[:input] || {},
              tool_result: tool_result,
              content: nil
            )

            messages << {
              role: "user",
              content: "[Tool result · #{tc[:name]}]\n#{tool_result.to_json}"
            }
          end
          next
        end

        assistant_text = result[:text].to_s
        break
      end

      assistant_text ||= "(no response from provider)"

      assistant_msg = AssistantMessage.create!(
        user: user, session_id: session_id,
        role: "assistant",
        content: assistant_text,
        provider: provider_meta[:provider],
        model: provider_meta[:model],
        tokens_in: provider_meta[:tokens_in],
        tokens_out: provider_meta[:tokens_out],
        latency_ms: provider_meta[:latency_ms]
      )

      Result.new(user_message: user_msg, assistant_message: assistant_msg, tool_messages: tool_messages)
    rescue Errors::ProviderError => e
      assistant_msg = AssistantMessage.create!(
        user: user, session_id: session_id,
        role: "assistant",
        content: "Provider error (#{e.class.name.demodulize}): #{e.message}",
        provider: e.provider
      )
      raise unless defined?(user_msg) && user_msg
      Result.new(user_message: user_msg, assistant_message: assistant_msg, tool_messages: tool_messages || [])
    end

    private

    def lookup_attachment(attachment_id)
      return nil if attachment_id.blank?
      msg = user.assistant_messages.find_by(id: attachment_id)
      msg&.file&.attachment
    end

    def persist_user_message(content, session_id, attachment)
      msg = AssistantMessage.create!(
        user: user, session_id: session_id, role: "user", content: content
      )
      # If the user attached a file via the attachments endpoint, that creates
      # a placeholder AssistantMessage. We "promote" the file by re-attaching
      # it to this user message so the chat history is coherent.
      if attachment.present? && attachment.record_id != msg.id
        blob = attachment.blob
        msg.file.attach(blob)
      end
      msg
    end
  end
end
