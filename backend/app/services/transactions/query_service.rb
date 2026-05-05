module Transactions
  class QueryService
    def initialize(user, params)
      @user   = user
      @params = params
    end

    def call
      limit  = [(@params[:limit] || 50).to_i, 200].min
      offset = (@params[:cursor] || 0).to_i

      scope = @user.transactions.order(date: :desc, id: :desc)

      scope = scope.where(transaction_type: @params[:transaction_type]) if @params[:transaction_type].present?
      scope = scope.where("date >= ?", @params[:start_date])            if @params[:start_date].present?
      scope = scope.where("date <= ?", @params[:end_date])              if @params[:end_date].present?
      scope = scope.where(linked_account_type: @params[:linked_account_type]) if @params[:linked_account_type].present?
      scope = scope.where(linked_account_id: @params[:linked_account_id])     if @params[:linked_account_id].present?

      if @params[:search].present?
        term = "%#{@params[:search]}%"
        scope = scope.where("description ILIKE ? OR bank_ref ILIKE ?", term, term)
      end

      total = scope.count
      items = scope.offset(offset).limit(limit)
      next_cursor = offset + limit < total ? offset + limit : nil

      { items: items, total: total, next_cursor: next_cursor }
    end
  end
end
