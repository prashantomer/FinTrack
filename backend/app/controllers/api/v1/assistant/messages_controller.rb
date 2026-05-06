module Api
  module V1
    module Assistant
      class MessagesController < ApplicationController
        # GET /api/v1/assistant/messages?session_id=...&limit=...&before=...
        def index
          scope = current_user.assistant_messages.chronological
          scope = scope.where(session_id: params[:session_id]) if params[:session_id].present?
          scope = scope.where("id < ?", params[:before]) if params[:before].present?
          limit = (params[:limit] || 100).to_i.clamp(1, 500)

          msgs = scope.limit(limit).to_a
          render_success(data: msgs.map { |m| serialize(m) })
        end

        # POST /api/v1/assistant/messages
        def create
          payload = create_params
          session_id = payload[:session_id].presence || SecureRandom.uuid

          result = ::Assistants::Conversation.new(current_user).run!(
            content: payload[:content].to_s,
            session_id: session_id,
            attachment_id: payload[:attachment_id],
            reference_ids: Array(payload[:reference_ids])
          )

          render_created(data: {
            session_id: session_id,
            user_message:      serialize(result.user_message),
            assistant_message: serialize(result.assistant_message),
            tool_messages:     result.tool_messages.map { |m| serialize(m) }
          })
        rescue ::Assistants::Errors::ProviderError => e
          render_error(
            message: e.message,
            errors: { provider: e.provider, code: e.code, error_class: e.class.name.demodulize },
            status: :bad_gateway
          )
        end

        # POST /api/v1/assistant/messages/:id/pin
        def pin
          msg = current_user.assistant_messages.find(params[:id])
          msg.update!(pinned: true)
          render_success(data: serialize(msg))
        end

        # DELETE /api/v1/assistant/messages/:id/pin
        def unpin
          msg = current_user.assistant_messages.find(params[:id])
          msg.update!(pinned: false)
          render_success(data: serialize(msg))
        end

        # DELETE /api/v1/assistant/messages
        def destroy_all
          current_user.assistant_messages.delete_all
          render_success(data: { deleted: true })
        end

        private

        def create_params
          params.permit(:content, :session_id, :attachment_id, reference_ids: [])
        end

        def serialize(msg)
          file_url = msg.file.attached? ? rails_blob_url(msg.file, only_path: true) : nil
          {
            id: msg.id,
            session_id: msg.session_id,
            role: msg.role,
            content: msg.content,
            tool_name: msg.tool_name,
            tool_arguments: msg.tool_arguments,
            tool_result: msg.tool_result,
            pinned: msg.pinned,
            file_name: msg.file.attached? ? msg.file.filename.to_s : nil,
            file_url: file_url,
            provider: msg.provider,
            model: msg.model,
            tokens_in: msg.tokens_in,
            tokens_out: msg.tokens_out,
            latency_ms: msg.latency_ms,
            created_at: msg.created_at
          }
        end
      end
    end
  end
end
