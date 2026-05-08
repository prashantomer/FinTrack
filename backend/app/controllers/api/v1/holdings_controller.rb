module Api
  module V1
    class HoldingsController < ApplicationController
      before_action :set_holding, only: [ :show, :update, :destroy ]

      # GET /api/v1/holdings?type=Folio|EquityHolding
      # Backed by the cached `holdings` table — no per-request aggregation.
      def index
        page_size = [ [ ((params[:page_size] || 50).to_i), 1 ].max, 200 ].min
        page      = [ ((params[:page] || 1).to_i), 1 ].max
        offset    = (page - 1) * page_size

        scope = current_user.holdings.includes(user_instrument: :instrument, platform_account: :platform)
        scope = scope.where(type: params[:type]) if params[:type].present?
        scope = scope.open    if params[:status] == "open"
        scope = scope.closed  if params[:status] == "closed"

        total = scope.count
        items = scope.order(current_value: :desc, id: :asc).offset(offset).limit(page_size)

        render_success(
          data:      items,
          meta_data: { total: total, page: page, page_size: page_size }
        )
      end

      def show
        render_success(data: @holding)
      end

      # Folio create — kept for users who track an MF without yet importing
      # any investment lots.
      def create
        holding = current_user.folios.create!(folio_params.merge(type: "Folio"))
        render_created(data: holding)
      rescue ActiveRecord::RecordInvalid => e
        render_error(message: "Validation failed", errors: e.record.errors.to_hash)
      end

      # Update typically used to correct a folio_number on a Folio row. Other
      # cached stat columns are owned by Holdings::RefreshService and shouldn't
      # be edited directly through this endpoint.
      def update
        @holding.update!(holding_params.except(:user_instrument_id, :platform_account_id, :type))
        render_success(data: @holding)
      rescue ActiveRecord::RecordInvalid => e
        render_error(message: "Validation failed", errors: e.record.errors.to_hash)
      end

      def destroy
        @holding.destroy
        head :no_content
      end

      # POST /api/v1/holdings/refresh — recompute the cache for this user
      def refresh
        Holdings::RefreshService.refresh_all_for(current_user)
        render_success(data: { count: current_user.holdings.count })
      end

      private

      def set_holding
        @holding = current_user.holdings.includes(user_instrument: :instrument, platform_account: :platform).find(params[:id])
      end

      def holding_params
        params.permit(:user_instrument_id, :platform_account_id, :folio_number, :folio_id, :notes, :type).tap do |p|
          p[:folio_number] ||= p.delete(:folio_id)
        end
      end

      # `create` only accepts Folio shape; EquityHolding rows are auto-created
      # by RefreshService as Investment lots come in.
      def folio_params
        params.permit(:user_instrument_id, :platform_account_id, :folio_number, :folio_id, :notes).tap do |p|
          p[:folio_number] ||= p.delete(:folio_id)
        end
      end
    end
  end
end
