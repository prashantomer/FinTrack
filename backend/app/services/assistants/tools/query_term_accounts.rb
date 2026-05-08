module Assistants
  module Tools
    class QueryTermAccounts < Base
      def name; "query_term_accounts"; end
      def description
        "List the user's FD and PPF accounts with maturity info and balances. Optionally filter by type or active state."
      end
      def input_schema
        {
          type: "object",
          properties: {
            type:           { type: "string", enum: %w[fd ppf], description: "Filter by FD or PPF" },
            include_closed: { type: "boolean", default: false }
          },
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        scope = user.term_accounts.includes(parent_account: :bank).order(:maturity_date)
        scope = scope.where(account_type: a["type"]) if a["type"].present?
        scope = scope.active unless a["include_closed"] == true

        items = scope.map do |ta|
          days_remaining = ta.maturity_date && (ta.maturity_date - Date.current).to_i
          {
            id: ta.id,
            type: ta.account_type,
            account_number: ta.account_number,
            bank: ta.parent_account&.bank&.short_name,
            balance: fmt_amount(ta.balance),
            amount: fmt_amount(ta.amount),
            interest_rate: ta.interest_rate,
            open_date: ta.open_date&.to_s,
            maturity_date: ta.maturity_date&.to_s,
            maturity_amount: fmt_amount(ta.maturity_amount),
            days_remaining: days_remaining,
            is_active: ta.is_active
          }
        end
        { count: items.size, term_accounts: items }
      end
    end
  end
end
