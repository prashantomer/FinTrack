module Investments
  class QueryService
    def initialize(user, params)
      @user   = user
      @params = params
    end

    def call
      page_size = [ [ (@params[:page_size] || @params[:limit] || 20).to_i, 1 ].max, 200 ].min
      page      = [ (@params[:page] || 1).to_i, 1 ].max
      offset    = (page - 1) * page_size

      scope = @user.investments.includes(:user_instrument)
      scope = scope.where(investment_type: Array(@params[:investment_type])) if @params[:investment_type].present?

      total = scope.count
      items = scope.order(purchase_date: :desc, id: :desc).offset(offset).limit(page_size)

      { items: items, total: total, page: page, page_size: page_size }
    end
  end
end
