module Transactions
  class QueryService
    SORTABLE = {
      "date"    => [ :date, :id ],
      # Account sort puts everything bucketed by linked account (NULLs last),
      # then date desc within the bucket so the row order inside an account
      # still feels familiar.
      "account" => [ :linked_account_id, :date, :id ]
    }.freeze

    def initialize(user, params)
      @user   = user
      @params = params
    end

    def call
      limit  = [ (@params[:limit] || 50).to_i, 200 ].min
      offset = (@params[:cursor] || 0).to_i

      scope = apply_filters(@user.transactions.unscope(:order))
      scope = apply_sort(scope)

      total = scope.count
      items = scope.offset(offset).limit(limit)
      next_cursor = offset + limit < total ? offset + limit : nil

      { items: items, total: total, next_cursor: next_cursor }
    end

    private

    def apply_filters(scope)
      scope = scope.where(transaction_type:    @params[:transaction_type])    if @params[:transaction_type].present?
      scope = scope.where(source:              @params[:source])              if @params[:source].present?
      scope = scope.where("date >= ?",         @params[:start_date])          if @params[:start_date].present?
      scope = scope.where("date <= ?",         @params[:end_date])            if @params[:end_date].present?
      scope = scope.where(linked_account_type: @params[:linked_account_type]) if @params[:linked_account_type].present?
      scope = scope.where(linked_account_id:   @params[:linked_account_id])   if @params[:linked_account_id].present?

      if @params[:search].present?
        term = "%#{@params[:search]}%"
        scope = scope.where("description ILIKE ? OR bank_ref ILIKE ?", term, term)
      end
      scope
    end

    def apply_sort(scope)
      key  = SORTABLE.key?(@params[:sort_by]) ? @params[:sort_by] : "date"
      dir  = (@params[:sort_dir].to_s.downcase == "asc") ? :asc : :desc
      cols = SORTABLE.fetch(key)
      # `id` is always desc so identical-key rows have a deterministic order
      # without the UI needing a secondary-sort selector.
      order = cols.each_with_index.to_h { |c, i| [ c, (i.zero? ? dir : (c == :id ? :desc : :desc)) ] }
      scope.order(order)
    end
  end
end
