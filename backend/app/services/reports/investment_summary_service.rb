module Reports
  class InvestmentSummaryService
    def initialize(user)
      @user = user
    end

    def call
      investments = @user.investments.all
      by_type     = investments.group_by(&:investment_type)

      holdings = by_type.map do |inv_type, invs|
        invested = invs.sum { |i| i.amount_invested.to_f }
        current  = invs.sum { |i| (i.current_value || i.amount_invested).to_f }
        {
          investment_type: inv_type,
          total_invested:  invested,
          current_value:   current,
          unrealized_gain: current - invested,
          count:           invs.count
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
