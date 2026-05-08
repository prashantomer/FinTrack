module Api
  module V1
    module Assistant
      class SessionsController < ApplicationController
        # POST /api/v1/assistant/sessions
        # Returns a fresh session_id. No DB row is created — the first message
        # in this session is what binds it.
        def create
          render_created(data: { session_id: SecureRandom.uuid })
        end
      end
    end
  end
end
