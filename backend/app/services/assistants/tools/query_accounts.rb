module Assistants
  module Tools
    class QueryAccounts < Base
      def name; "query_accounts"; end
      def description
        "List the user's bank accounts with current balances. Defaults to open accounts only."
      end
      def input_schema
        {
          type: "object",
          properties: {
            include_closed: { type: "boolean", default: false }
          },
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        scope = user.accounts.includes(:bank).order(balance: :desc)
        scope = scope.open unless a["include_closed"] == true
        items = scope.map do |acc|
          {
            id: acc.id,
            nickname: acc.nickname,
            bank: acc.bank&.short_name,
            account_type: acc.account_type,
            balance: fmt_amount(acc.balance),
            closed_date: acc.closed_date&.to_s
          }
        end
        { count: items.size, accounts: items }
      end
    end
  end
end
