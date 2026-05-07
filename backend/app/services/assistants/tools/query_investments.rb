module Assistants
  module Tools
    class QueryInvestments < Base
      def name; "query_investments"; end
      def description
        "List the user's investment trades (stocks, mutual funds). Each row is a single buy or sell trade with its own date, quantity, and price. Optional filters by investment_type, trade_type, and substring name search."
      end
      def input_schema
        {
          type: "object",
          properties: {
            type:       { type: "string", enum: %w[stock mutual_fund] },
            trade_type: { type: "string", enum: %w[buy sell] },
            search:     { type: "string", description: "Substring matched against name" },
            limit:      { type: "integer", minimum: 1, maximum: 200, default: 100 }
          },
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        scope = user.investments.order(purchase_date: :desc)
        scope = scope.where(investment_type: a["type"]) if a["type"].present?
        scope = scope.where(trade_type: a["trade_type"]) if a["trade_type"].present?
        scope = scope.where("name ILIKE ?", "%#{a['search']}%") if a["search"].present?
        scope = scope.limit((a["limit"] || 100).to_i.clamp(1, 200))

        items = scope.map do |inv|
          amount = inv.amount_invested.to_f
          current = (inv.current_value || inv.amount_invested).to_f
          gain    = inv.buy? ? (current - amount) : 0.0
          {
            id: inv.id,
            trade_type: inv.trade_type,
            type: inv.investment_type,
            name: inv.name,
            date: inv.purchase_date.to_s,
            amount: fmt_amount(amount),
            price: inv.price,
            current_value: inv.buy? ? fmt_amount(current) : nil,
            unrealized_gain: inv.buy? ? fmt_amount(gain) : nil,
            quantity: inv.quantity, units: inv.units,
            order_id: inv.order_id, trade_id: inv.trade_id,
            folio_number: inv.folio_number
          }
        end
        { count: items.size, investments: items }
      end
    end
  end
end
