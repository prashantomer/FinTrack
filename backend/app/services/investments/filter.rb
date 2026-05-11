module Investments
  # Investment-specific filter. Declares the accepted query fields and how to
  # apply them to a scope. Reusable, expandable: add a new field by adding one
  # `attribute` line and one `with_*` clause in #apply.
  class Filter < ::Queries::FilterBase
    # Fully-qualified to avoid ambiguity with `instruments.name` when the scope
    # eager-loads the instrument catalogue.
    SEARCH_COLUMNS = %w[investments.name investments.order_id investments.trade_id].freeze
    SEARCH_CASTS   = { "investments.transaction_public_id" => "text" }.freeze

    attribute :investment_type, array: true
    attribute :trade_type
    attribute :source
    attribute :search
    attribute :date_from, :date_to
    attribute :sort_by, :sort_dir

    def apply(scope)
      scope = with_in(scope, "investments.investment_type", investment_type)
      scope = with_eq(scope, "investments.trade_type", trade_type)
      scope = with_eq(scope, "investments.source", source)
      scope = with_range(scope, "investments.purchase_date", gte: date_from, lte: date_to)
      with_ilike_any(scope, SEARCH_COLUMNS + [ "investments.transaction_public_id" ], search, casts: SEARCH_CASTS)
    end

    # Resolves the sort_by/sort_dir attributes to a hash suitable for
    # `scope.order(...)`. Defaults to purchase_date desc + id desc when not
    # specified. Only "date" is exposed; secondary sort by id keeps ties
    # deterministic so the UI doesn't need its own tiebreaker.
    def order_clause
      dir = (sort_dir.to_s.downcase == "asc") ? :asc : :desc
      { "investments.purchase_date" => dir, "investments.id" => :desc }
    end
  end
end
