module Api
  module V1
    class CleanupController < ApplicationController
      # POST /api/v1/cleanup/preview
      # Body: wizard config (see Cleanup::ScopeBuilder)
      # Returns: { sectors: [{ sector, count, samples }], total }
      def preview
        result = Cleanup::PreviewService.new(current_user, cleanup_params).call
        render_success(data: result)
      end

      # POST /api/v1/cleanup/execute
      # Body: wizard config + `confirm: "DELETE"`
      # Returns: { deleted: { sector => count, ... }, total }
      #
      # Requires the literal "DELETE" string as a confirm token so a stray
      # POST can't wipe a user. The frontend types this from a final
      # confirmation step.
      def execute
        unless params[:confirm].to_s == "DELETE"
          return render_error(message: "confirm token must be the literal string 'DELETE'", status: :unprocessable_content)
        end

        result = Cleanup::ExecuteService.new(current_user, cleanup_params).call
        render_success(data: result)
      end

      private

      def cleanup_params
        params.permit(
          :date_from, :date_to, :source, :active, :reset_balances,
          sectors:     [],
          account_ids: [],
          tags_any:    []
        ).to_h
      end
    end
  end
end
