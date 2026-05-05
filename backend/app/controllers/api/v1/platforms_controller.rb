module Api
  module V1
    class PlatformsController < ApplicationController
      def index
        render_success(data: Platform.order(:name))
      end

      def show
        render_success(data: Platform.find(params[:id]))
      end
    end
  end
end
