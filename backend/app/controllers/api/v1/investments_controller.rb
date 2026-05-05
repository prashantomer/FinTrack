module Api
  module V1
    class InvestmentsController < ApplicationController
      before_action :set_investment, only: [:show, :update, :destroy]

      def index
        result = Investments::QueryService.new(current_user, query_params).call
        render_success(
          data:      result[:items],
          meta_data: { total: result[:total], page: result[:page], page_size: result[:page_size] }
        )
      end

      def show
        render_success(data: @investment)
      end

      def create
        render_created(data: current_user.investments.create!(investment_params))
      end

      def update
        @investment.update!(investment_params)
        render_success(data: @investment)
      end

      def destroy
        @investment.destroy
        head :no_content
      end

      private

      def set_investment
        @investment = current_user.investments.includes(:user_instrument).find(params[:id])
      end

      def query_params
        p = params.permit(:page, :page_size, investment_type: [], type: [])
        p[:investment_type] = p.delete(:type) if p[:type].present? && p[:investment_type].blank?
        p
      end

      def investment_params
        p = params.permit(:investment_type, :type, :name, :amount_invested, :notes,
                          :user_instrument_id, :platform_account_id,
                          :quantity, :buy_price, :units, :nav_at_purchase, :folio_number,
                          :current_value, :purchase_date)
        p[:investment_type] ||= p.delete(:type)
        p
      end
    end
  end
end
