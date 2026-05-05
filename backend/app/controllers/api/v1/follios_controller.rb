module Api
  module V1
    class FolliosController < ApplicationController
      before_action :set_follio, only: [:show, :update, :destroy]

      def index
        page_size = [[((params[:page_size] || 20).to_i), 1].max, 200].min
        page      = [((params[:page] || 1).to_i), 1].max
        offset    = (page - 1) * page_size

        scope = current_user.follios.includes(user_instrument: :instrument, platform_account: :platform)
        total = scope.count
        items = scope.order(created_at: :desc).offset(offset).limit(page_size)

        render_success(
          data:      items,
          meta_data: { total: total, page: page, page_size: page_size }
        )
      end

      def show
        render_success(data: @follio)
      end

      def create
        follio = current_user.follios.create!(follio_params)
        follio = current_user.follios.includes(user_instrument: :instrument, platform_account: :platform).find(follio.id)
        render_created(data: follio)
      rescue ActiveRecord::RecordInvalid => e
        render_error(message: "Validation failed", errors: e.record.errors.to_hash)
      end

      def update
        @follio.update!(follio_params.except(:user_instrument_id, :platform_account_id))
        render_success(data: @follio)
      rescue ActiveRecord::RecordInvalid => e
        render_error(message: "Validation failed", errors: e.record.errors.to_hash)
      end

      def destroy
        @follio.destroy
        head :no_content
      end

      private

      def set_follio
        @follio = current_user.follios.includes(user_instrument: :instrument, platform_account: :platform).find(params[:id])
      end

      def follio_params
        params.permit(:user_instrument_id, :platform_account_id, :folio_number, :follio_id, :notes).tap do |p|
          p[:folio_number] ||= p.delete(:follio_id)
          p[:user_id] = current_user.id
        end
      end
    end
  end
end
