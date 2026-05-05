module Api
  module V1
    class BanksController < ApplicationController
      def index
        render_success(data: Bank.order(:name))
      end

      def show
        render_success(data: Bank.find(params[:id]))
      end
    end
  end
end
