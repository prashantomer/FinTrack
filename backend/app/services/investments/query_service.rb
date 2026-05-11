module Investments
  class QueryService
    # Accepts either an Investments::Filter or a raw params hash (back-compat).
    def initialize(user, filter_or_params)
      @user   = user
      @filter = filter_or_params.is_a?(Filter) ? filter_or_params : Filter.new(filter_or_params)
    end

    def call
      base  = @user.investments.unscope(:order).includes(user_instrument: :instrument)
      scope = @filter.apply(base)
      total = scope.count
      items = scope.reorder(@filter.order_clause)
                   .offset(@filter.offset)
                   .limit(@filter.page_size)

      { items: items, total: total, page: @filter.page, page_size: @filter.page_size }
    end
  end
end
