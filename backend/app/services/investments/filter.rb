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
    attribute :search
    attribute :date_from, :date_to

    def apply(scope)
      scope = with_in(scope, "investments.investment_type", investment_type)
      scope = with_eq(scope, "investments.trade_type", trade_type)
      scope = with_range(scope, "investments.purchase_date", gte: date_from, lte: date_to)
      with_ilike_any(scope, SEARCH_COLUMNS + [ "investments.transaction_public_id" ], search, casts: SEARCH_CASTS)
    end
  end
end
