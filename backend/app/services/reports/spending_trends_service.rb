module Reports
  class SpendingTrendsService
    def initialize(user, params)
      @user   = user
      @months = (params[:months] || 6).to_i.clamp(1, 24)
    end

    def call
      month_expr = Arel.sql("TO_CHAR(date, 'YYYY-MM')")
      rows = @user.transactions
                  .active
                  .group(month_expr, :transaction_type)
                  .order(month_expr)
                  .sum(:amount)

      by_month = Hash.new { |h, k| h[k] = { inbound: 0.0, outbound: 0.0 } }
      rows.each do |(month, txn_type), total|
        if txn_type == "credit"
          by_month[month][:inbound] += total.to_f
        else
          by_month[month][:outbound] += total.to_f
        end
      end

      sorted_months = by_month.keys.sort.last(@months)
      trends = sorted_months.map do |m|
        d = by_month[m]
        { month: m, inbound: d[:inbound], outbound: d[:outbound], net: d[:inbound] - d[:outbound] }
      end

      { months: trends }
    end
  end
end
