module Reports
  class InvestmentSummaryService
    def initialize(user)
      @user = user
    end

    def call
      # Delegate to PortfolioService for consistent cost-basis math (held shares
      # only, not the original buy quantity at today's price).
      portfolio = ::Reports::PortfolioService.new(@user).call

      holdings = portfolio[:positions].group_by { |p| p[:type] }.map do |inv_type, ps|
        {
          investment_type: inv_type,
          total_invested:  ps.sum { |p| p[:total_invested] },
          current_value:   ps.sum { |p| p[:current_value] },
          unrealized_gain: ps.sum { |p| p[:unrealized_gain] },
          count:           ps.size
        }
      end

      total_invested  = holdings.sum { |h| h[:total_invested] }
      total_current   = holdings.sum { |h| h[:current_value] }

      {
        holdings:            holdings,
        total_invested:      total_invested,
        total_current_value: total_current,
        total_unrealized_gain: total_current - total_invested
      }
    end
  end
end
