module Imports
  # Adapters that translate a parsed CSV row from a particular source format
  # into the "normalized" hash shape that ProcessInvestmentRowService expects.
  #
  # Pattern: each adapter responds to .transform(row_hash) → Hash. Detection
  # is done once per file via .for_headers(headers).
  module InvestmentFormatAdapters
    ZERODHA_SIGNATURE = %i[symbol isin trade_date segment].freeze

    def self.for_headers(headers)
      symbols = headers.compact.map { |h| h.is_a?(Symbol) ? h : h.to_s.strip.downcase.to_sym }
      return Zerodha if (ZERODHA_SIGNATURE - symbols).empty?
      Default
    end

    module Default
      def self.transform(row)
        row.to_h
      end
    end

    # Zerodha tradebook export — covers both Coin (mutual funds) and Kite
    # (equities), which share an identical column layout. The `segment` field
    # disambiguates: "MF" routes to Coin, "EQ" routes to Kite.
    # Headers: symbol, isin, trade_date, exchange, segment, series, trade_type,
    #          auction, quantity, price, trade_id, order_id, order_execution_time
    module Zerodha
      COIN_PLATFORM_NAME = "Coin by Zerodha".freeze
      KITE_PLATFORM_NAME = "Kite by Zerodha".freeze

      SEGMENT_TO_TYPE = {
        "MF" => "mutual_fund",
        "EQ" => "stock"
      }.freeze

      def self.transform(row)
        row = row.to_h

        segment = row[:segment].to_s.strip.upcase
        investment_type = SEGMENT_TO_TYPE[segment]
        raise "segment \"#{row[:segment]}\" is not supported (expected MF or EQ)" if investment_type.nil?

        quantity = row[:quantity].to_s.strip.presence&.to_f
        price    = row[:price].to_s.strip.presence&.to_f
        amount_invested = (quantity && price) ? (quantity * price).round(2) : nil

        {
          trade_type:      row[:trade_type].to_s.strip.downcase.presence,
          investment_type: investment_type,
          name:            row[:symbol].to_s.strip.presence,
          isin:            row[:isin].to_s.strip.presence,
          ticker_symbol:   investment_type == "stock" ? row[:symbol].to_s.strip.presence : nil,
          exchange:        row[:exchange].to_s.strip.presence,
          amount_invested: amount_invested,
          purchase_date:   row[:trade_date].to_s.strip.presence,
          quantity:        investment_type == "stock"       ? quantity : nil,
          units:           investment_type == "mutual_fund" ? quantity : nil,
          price:           price,
          order_id:        row[:order_id].to_s.strip.presence,
          trade_id:        row[:trade_id].to_s.strip.presence,
          platform_name:   investment_type == "stock" ? KITE_PLATFORM_NAME : COIN_PLATFORM_NAME
        }
      end
    end
  end
end
