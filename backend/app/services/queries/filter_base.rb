module Queries
  # Base class for query filter objects.
  #
  # Subclasses declare which fields they accept via `attribute :name`. The base
  # class handles permitting from controller params and exposing them as readers
  # for use in the matching `*::QueryService`. Pagination (page, page_size) is
  # built in.
  #
  # Usage:
  #   class InvestmentFilter < FilterBase
  #     attribute :investment_type, array: true
  #     attribute :trade_type
  #     attribute :search
  #     attribute :date_from, :date_to
  #   end
  #
  #   filter = InvestmentFilter.from_params(params)
  #   filter.search? # true if value is present
  #   filter.search  # the value
  #
  # Controllers stay tiny:
  #   def index
  #     filter = InvestmentFilter.from_params(params)
  #     result = Investments::QueryService.new(current_user, filter).call
  #     ...
  #   end
  class FilterBase
    DEFAULT_PAGE      = 1
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE     = 200

    class << self
      def attribute(*names, array: false)
        @attributes ||= {}
        names.each do |name|
          @attributes[name.to_sym] = { array: array }
          define_method(name) { @attrs[name.to_sym] }
          define_method("#{name}?") { v = @attrs[name.to_sym]; v.respond_to?(:empty?) ? !v.empty? : !v.nil? }
        end
      end

      def attributes
        (@attributes || {}).merge(superclass.respond_to?(:attributes) ? superclass.attributes : {})
      end

      def from_params(params)
        permitted_keys = attributes.flat_map { |k, opts| opts[:array] ? [ { k => [] } ] : [ k ] }
        permitted_keys.concat([ :page, :page_size, :limit, :cursor ])
        new(params.permit(*permitted_keys))
      end
    end

    attr_reader :raw

    def initialize(params)
      @raw   = params
      @attrs = self.class.attributes.each_with_object({}) do |(name, opts), hash|
        v = params[name]
        v = Array(v).reject(&:blank?) if opts[:array]
        v = v.presence
        hash[name] = v
      end
    end

    # Pagination ------------------------------------------------------------

    def page
      [ (@raw[:page] || DEFAULT_PAGE).to_i, 1 ].max
    end

    def page_size
      raw_size = (@raw[:page_size] || @raw[:limit] || DEFAULT_PAGE_SIZE).to_i
      [ [ raw_size, 1 ].max, MAX_PAGE_SIZE ].min
    end

    def offset
      (page - 1) * page_size
    end

    def cursor
      @raw[:cursor].presence&.to_i
    end

    # Apply this filter to a base scope. Subclasses override.
    def apply(scope)
      scope
    end

    # Convenience: scope helpers subclasses can use.
    protected

    def with_in(scope, column, value)
      value.present? ? scope.where(column => value) : scope
    end

    def with_eq(scope, column, value)
      value.present? ? scope.where(column => value) : scope
    end

    def with_range(scope, column, gte: nil, lte: nil)
      scope = scope.where("#{column} >= ?", gte) if gte.present?
      scope = scope.where("#{column} <= ?", lte) if lte.present?
      scope
    end

    def with_ilike_any(scope, columns, term, casts: {})
      return scope if term.blank?
      like = "%#{term}%"
      sql_parts = columns.map do |c|
        cast = casts[c]
        cast ? "#{c}::#{cast} ILIKE :like" : "#{c} ILIKE :like"
      end
      scope.where(sql_parts.join(" OR "), like: like)
    end
  end
end
