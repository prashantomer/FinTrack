module Api
  module V1
    module Assistant
      class AttachmentsController < ApplicationController
        MAX_BYTES = 5.megabytes
        ALLOWED_CONTENT_TYPES = %w[text/csv application/csv text/plain application/vnd.ms-excel].freeze

        # POST /api/v1/assistant/attachments
        def create
          file = params[:file]
          return render_error(message: "file is required", status: :bad_request) if file.blank?
          return render_error(message: "file too large (max 5 MB)", status: :unprocessable_content) if file.size > MAX_BYTES

          # Stash the upload as a placeholder AssistantMessage (role=user, no content yet).
          # The next /messages POST will reference this attachment_id and promote the file
          # onto the actual user message.
          msg = current_user.assistant_messages.create!(
            session_id: SecureRandom.uuid,
            role: "user",
            content: nil
          )
          msg.file.attach(io: file.tempfile, filename: file.original_filename, content_type: file.content_type)
          render_created(data: {
            attachment_id: msg.id,
            filename: msg.file.filename.to_s,
            byte_size: msg.file.byte_size,
            content_type: msg.file.content_type
          })
        end

        # GET /api/v1/assistant/attachments/:id
        def show
          msg = current_user.assistant_messages.find(params[:id])
          return render_error(message: "no file attached", status: :not_found) unless msg.file.attached?
          send_data msg.file.download,
                    filename: msg.file.filename.to_s,
                    type: msg.file.content_type,
                    disposition: "attachment"
        end
      end
    end
  end
end
