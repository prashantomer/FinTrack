module Api
  module V1
    class ClientErrorsController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        CLIENT_ERRORS_LOGGER.error(
          "message=#{params[:message].inspect} | " \
          "url=#{params[:url].inspect} | " \
          "stack=#{params[:stack].inspect} | " \
          "component_stack=#{params[:component_stack].inspect}"
        )
        head :no_content
      end
    end
  end
end
