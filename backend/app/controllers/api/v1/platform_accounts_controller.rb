module Api
  module V1
    class PlatformAccountsController < ApplicationController
      before_action :set_platform_account, only: [:show, :update, :destroy]

      def index
        render_success(data: current_user.platform_accounts.includes(:platform).order(:nickname))
      end

      def show
        render_success(data: @platform_account)
      end

      def create
        pa = current_user.platform_accounts.build(platform_account_params)
        if pa.save
          pa = current_user.platform_accounts.includes(:platform).find(pa.id)
          render_created(data: pa)
        else
          render_error(message: "Validation failed", errors: pa.errors.to_hash)
        end
      end

      def update
        if @platform_account.update(platform_account_params)
          render_success(data: @platform_account)
        else
          render_error(message: "Validation failed", errors: @platform_account.errors.to_hash)
        end
      end

      def destroy
        @platform_account.destroy
        head :no_content
      end

      private

      def set_platform_account
        @platform_account = current_user.platform_accounts.includes(:platform).find(params[:id])
      end

      def platform_account_params
        params.permit(:nickname, :platform_id, :account_id)
      end
    end
  end
end
