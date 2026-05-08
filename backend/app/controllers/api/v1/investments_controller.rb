module Api
  module V1
    class InvestmentsController < ApplicationController
      before_action :set_investment, only: [ :show, :update ]

      def index
        filter = Investments::Filter.from_params(params)
        result = Investments::QueryService.new(current_user, filter).call
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

      # Manual investments are editable but only on free-text fields. Type,
      # amounts, dates, and broker IDs would desync the holding cache and the
      # paired bank transaction, so we don't let those drift after creation.
      # Imported rows are fully frozen — the CSV is the source of truth.
      def update
        unless @investment.editable?
          return render_error(message: "Imported investments cannot be edited", status: :forbidden)
        end
        @investment.update!(editable_investment_params)
        render_success(data: @investment)
      end

      # PATCH /api/v1/investments/folio
      # Bulk-update folio_number for every investment of the user that belongs
      # to the given user_instrument. Used to correct auto-generated folios on
      # the Holdings page in one shot instead of editing each lot separately.
      def update_folio
        user_instrument_id = params.require(:user_instrument_id).to_i
        folio_number       = params[:folio_number].to_s.strip.presence

        scope   = current_user.investments.where(user_instrument_id: user_instrument_id)
        updated = scope.update_all(folio_number: folio_number)

        # `update_all` bypasses model callbacks — refresh the Holding cache
        # manually so the Holdings page picks up the new folio_number.
        Holdings::RefreshService.refresh_for_user_instrument(current_user, user_instrument_id)

        render_success(data: {
          user_instrument_id: user_instrument_id,
          folio_number:       folio_number,
          updated:            updated
        })
      end

      private

      def set_investment
        @investment = current_user.investments.includes(:user_instrument).find(params[:id])
      end

      def investment_params
        p = params.permit(:investment_type, :type, :trade_type, :name, :amount_invested, :notes,
                          :user_instrument_id, :platform_account_id,
                          :quantity, :units, :price, :order_id, :trade_id, :folio_number,
                          :current_value, :purchase_date)
        p[:investment_type] ||= p.delete(:type)
        p
      end

      # Whitelist for #update on manual rows — notes only. Anything else is
      # silently dropped rather than 422'd so a UI sending a full payload still
      # succeeds without leaking which fields it tried to mutate.
      def editable_investment_params
        params.permit(:notes)
      end
    end
  end
end
