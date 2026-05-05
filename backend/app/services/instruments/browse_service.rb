module Instruments
  class BrowseService
    def initialize(params)
      @params = params
    end

    def call
      limit  = [ (@params[:limit] || 50).to_i, 200 ].min
      offset = (@params[:cursor] || 0).to_i

      scope = Instrument.alphabetical
      scope = scope.where(investment_type: @params[:investment_type]) if @params[:investment_type].present?

      if @params[:search].present?
        term  = "%#{@params[:search]}%"
        scope = scope.where("name ILIKE ? OR ticker_symbol ILIKE ? OR fund_house ILIKE ?", term, term, term)
      end

      total = scope.count
      items = scope.offset(offset).limit(limit)
      next_cursor = offset + limit < total ? offset + limit : nil

      {
        items:       items.map { |i| instrument_hash(i) },
        next_cursor: next_cursor,
        has_more:    next_cursor.present?
      }
    end

    private

    def instrument_hash(i)
      {
        id: i.id, name: i.name, investment_type: i.investment_type,
        ticker_symbol: i.ticker_symbol, isin: i.isin,
        exchange: i.exchange, fund_house: i.fund_house,
        created_at: i.created_at
      }
    end
  end
end
