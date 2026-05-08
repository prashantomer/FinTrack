module Assistants
  module Tools
    # Searches the GLOBAL instruments catalogue (shared reference data, not
    # user-scoped). Used during CSV conversion to resolve broker symbols
    # (e.g. "HDFCBANK", "SBIN") into FinTrack instrument records — name, ISIN,
    # exchange, etc.
    class LookupInstruments < Base
      def name; "lookup_instruments"; end

      def description
        "Search FinTrack's global instruments catalogue. Use this during CSV " \
        "conversion to resolve a broker symbol (stocks: 'HDFCBANK', 'SBIN'; " \
        "mutual funds have no ticker — pass the fund NAME instead) into the " \
        "canonical Instrument record so you can fill in name, ISIN, exchange, " \
        "fund_house. Pass at least one of: symbol, isin, or name. Matching is " \
        "case-insensitive substring. The `symbol` argument matches BOTH " \
        "ticker_symbol AND name, so a fund name passed there will still find " \
        "the right MF instrument."
      end

      def input_schema
        {
          type: "object",
          properties: {
            symbol: { type: "string", description: "Stock ticker (e.g. HDFCBANK) OR mutual-fund name. Searches both ticker_symbol and name." },
            isin:   { type: "string", description: "ISIN, e.g. INE040A01034" },
            name:   { type: "string", description: "Substring of instrument name (interchangeable with symbol for MFs)" },
            type:   { type: "string", enum: %w[stock mutual_fund] },
            limit:  { type: "integer", minimum: 1, maximum: 25, default: 10 }
          },
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        symbol = a["symbol"].to_s.strip
        isin   = a["isin"].to_s.strip
        name_q = a["name"].to_s.strip
        return { error: "missing_query", message: "Provide at least one of: symbol, isin, name." } if symbol.empty? && isin.empty? && name_q.empty?

        scope = ::Instrument.alphabetical
        scope = scope.where(investment_type: a["type"]) if a["type"].present?

        # Symbol matches BOTH ticker_symbol and name — for MFs (which have no
        # ticker), passing the fund name in `symbol` should still find the row.
        if symbol.present?
          like = "%#{symbol}%"
          scope = scope.where("ticker_symbol ILIKE ? OR name ILIKE ?", like, like)
        end
        scope = scope.where("isin ILIKE ?", "%#{isin}%") if isin.present?
        scope = scope.where("name ILIKE ?", "%#{name_q}%") if name_q.present?

        limit = (a["limit"] || 10).to_i.clamp(1, 25)
        items = scope.limit(limit).map do |i|
          # For MFs, surface the name as the "ticker" so callers building
          # broker-style mappings see something useful in that field.
          effective_ticker = i.ticker_symbol.presence || (i.mutual_fund? ? i.name : nil)
          {
            id: i.id,
            name: i.name,
            ticker_symbol: effective_ticker,
            isin: i.isin,
            exchange: i.exchange,
            fund_house: i.fund_house,
            investment_type: i.investment_type
          }
        end

        { count: items.size, instruments: items }
      end
    end
  end
end
