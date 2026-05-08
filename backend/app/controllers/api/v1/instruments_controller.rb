module Api
  module V1
    class InstrumentsController < ApplicationController
      before_action :set_instrument, only: [ :show, :update, :track, :untrack,
                                             :position, :lots, :linked_transactions, :price_history ]
      before_action :ensure_profile_allowed, only: [ :position, :lots, :linked_transactions, :price_history ]

      def index
        result = Instruments::BrowseService.new(browse_params).call
        render_success(
          data:      result[:items].map { |i| i.merge(type: i[:investment_type]) },
          meta_data: { next_cursor: result[:next_cursor], has_more: result[:has_more] }
        )
      end

      def types
        render_success(data: Instrument.distinct.pluck(:investment_type).sort)
      end

      def tracked
        render_success(data: current_user.tracked_instruments.alphabetical)
      end

      def user_instruments
        render_success(data: current_user.user_instruments.includes(:instrument).order("instruments.name"))
      end

      def show
        render_success(data: @instrument)
      end

      def create
        render_created(data: Instrument.create!(instrument_params))
      end

      def update
        @instrument.update!(instrument_params)
        render_success(data: @instrument)
      end

      def track
        ui = Instruments::TrackService.new(current_user, @instrument).track
        render_created(data: { id: ui.id, instrument_id: ui.instrument_id, added_at: ui.added_at })
      end

      def untrack
        Instruments::TrackService.new(current_user, @instrument).untrack
        head :no_content
      end

      # ── Profile endpoints ────────────────────────────────────────────────
      # Read-only. Render 404 (not 403) when the gate disallows so untracked
      # profiles don't leak existence to the client.

      def position
        render_success(data: profile_service.position)
      end

      def lots
        render_success(data: profile_service.lots)
      end

      def linked_transactions
        limit = params[:limit].presence&.to_i || Instruments::ProfileService::DEFAULT_TX_LIMIT
        render_success(data: profile_service.transactions(limit: limit))
      end

      def price_history
        days = params[:days].presence&.to_i || Instruments::ProfileService::DEFAULT_HISTORY_DAYS
        rows = profile_service.price_history(days: days)
        render_success(data: rows.map { |r| { date: r.price_date.iso8601, price: r.price.to_f, source: r.source } })
      end

      private

      def profile_service
        @profile_service ||= Instruments::ProfileService.new(current_user, @instrument)
      end

      def ensure_profile_allowed
        return if Instruments::ProfileGate.allowed?(current_user, @instrument)
        head :not_found
      end

      def set_instrument
        @instrument = Instrument.find(params[:id])
      end

      def browse_params
        p = params.permit(:investment_type, :type, :search, :cursor, :limit)
        p[:investment_type] ||= p.delete(:type)
        p
      end

      def instrument_params
        p = params.permit(:name, :investment_type, :type, :ticker_symbol, :isin, :exchange, :fund_house)
        p[:investment_type] ||= p.delete(:type)
        p
      end
    end
  end
end
