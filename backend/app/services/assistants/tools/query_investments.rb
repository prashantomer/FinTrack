module Assistants
  module Tools
    class QueryInvestments < Base
      def name; "query_investments"; end
      def description
        "List the user's investments (stocks, mutual funds). Optional type filter and substring search by name. Returns invested vs current value per holding."
      end
      def input_schema
        {
          type: "object",
          properties: {
            type:   { type: "string", enum: %w[stock mutual_fund] },
            search: { type: "string", description: "Substring matched against name" },
            limit:  { type: "integer", minimum: 1, maximum: 200, default: 100 }
          },
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        scope = user.investments.order(purchase_date: :desc)
        scope = scope.where(investment_type: a["type"]) if a["type"].present?
        scope = scope.where("name ILIKE ?", "%#{a['search']}%") if a["search"].present?
        scope = scope.limit((a["limit"] || 100).to_i.clamp(1, 200))

        items = scope.map do |inv|
          invested = inv.amount_invested.to_f
          current  = (inv.current_value || inv.amount_invested).to_f
          gain     = current - invested
          {
            id: inv.id,
            type: inv.investment_type,
            name: inv.name,
            purchase_date: inv.purchase_date.to_s,
            amount_invested: fmt_amount(invested),
            current_value: fmt_amount(current),
            gain_loss: fmt_amount(gain),
            gain_pct: invested > 0 ? format("%.2f", gain / invested * 100) : "0.00",
            quantity: inv.quantity, units: inv.units, folio_number: inv.folio_number
          }
        end
        { count: items.size, investments: items }
      end
    end
  end
end
