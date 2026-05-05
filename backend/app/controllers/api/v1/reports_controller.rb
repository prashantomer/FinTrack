module Api
  module V1
    class ReportsController < ApplicationController
      def dashboard
        render_success(data: Reports::DashboardService.new(current_user).call)
      end

      def spending_trends
        render_success(data: Reports::SpendingTrendsService.new(current_user, params.permit(:months)).call)
      end

      def investment_summary
        render_success(data: Reports::InvestmentSummaryService.new(current_user).call)
      end

      def refresh_dashboard
        Rails.cache.delete("dashboard/#{current_user.id}")
        render_success(data: {})
      end

      def dashboard_cache_status
        redis_ok = begin
          Rails.cache.read("__ping__")
          true
        rescue
          false
        end
        warm = Rails.cache.exist?("dashboard/#{current_user.id}")
        render_success(data: { redis_connected: redis_ok, cache_warm: warm, cache_ttl_seconds: nil })
      end

      def portfolio
        render_success(data: Reports::PortfolioService.new(current_user).call)
      end
    end
  end
end
