module Assistants
  # Builds the messages array sent to the LLM for a single chat turn.
  #
  # Composition:
  #   - System prompt (passed separately at the provider layer)
  #   - All `pinned` messages (oldest first)
  #   - All messages in the current `session_id`, chronological
  #   - The new user message (with optional attachment summary)
  class ContextBuilder
    MAX_HISTORY_MESSAGES = 30   # hard cap to keep token usage predictable

    attr_reader :user, :session_id

    def initialize(user, session_id)
      @user = user
      @session_id = session_id
    end

    def build(new_user_content:, attachment: nil, references: [])
      pinned = user.assistant_messages.pinned.chronological.where.not(session_id: session_id).to_a
      session_msgs = user.assistant_messages.in_session(session_id).chronological.to_a
      referenced = references.any? ? user.assistant_messages.where(id: references).to_a : []

      ordered = (pinned + referenced + session_msgs).uniq(&:id)
                                                    .last(MAX_HISTORY_MESSAGES)

      messages = ordered.flat_map { |m| message_to_provider_format(m) }

      user_payload = if attachment.present?
        attachment_intro = "[Attached file: #{attachment.filename} (#{attachment.byte_size} bytes, attachment_id=#{attachment.record.id})]"
        [ attachment_intro, new_user_content ].reject(&:blank?).join("\n\n")
      else
        new_user_content
      end

      messages << { role: "user", content: user_payload }
      messages
    end

    private

    # Convert AssistantMessage rows into role/content pairs the provider expects.
    # tool rows are pre-flattened to user-side text so providers without tool-use support don't break.
    def message_to_provider_format(msg)
      case msg.role
      when "user"
        body = msg.content.to_s
        body = "#{file_marker(msg)}\n#{body}".strip if msg.file.attached?
        return [] if body.blank?
        [ { role: "user", content: body } ]
      when "assistant"
        [ { role: "assistant", content: msg.content.to_s } ]
      when "tool"
        # Render tool result inline as plain text so it stays in the conversation
        # context even after a fresh provider call cycle. Surface generated files
        # so the user can ask follow-ups like "show me the converted rows".
        body = +"[Tool result · #{msg.tool_name}]\n#{(msg.tool_result || {}).to_json}"
        body << "\n#{file_marker(msg, label: "Generated file")}" if msg.file.attached?
        [ { role: "user", content: body } ]
      else
        []
      end
    end

    # A short, deterministic line the LLM can rely on to discover attachment_ids
    # from prior turns. Format is stable so the model can grep for it.
    def file_marker(msg, label: "Attached file")
      "[#{label}: #{msg.file.filename} · attachment_id=#{msg.id}]"
    end
  end
end
