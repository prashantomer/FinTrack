module Assistants
  module Tools
    class QueryTransactions < Base
      def name; "query_transactions"; end
      def description
        "List the user's transactions with optional filters. Use this for any question that needs specific transactions (date range, search by description/bank_ref, credit vs debit). Returns up to `limit` rows ordered by date desc."
      end

      def input_schema
        {
          type: "object",
          properties: {
            date_from: { type: "string", description: "ISO date YYYY-MM-DD inclusive" },
            date_to:   { type: "string", description: "ISO date YYYY-MM-DD inclusive" },
            type:      { type: "string", enum: %w[credit debit], description: "Filter by transaction type" },
            search:    { type: "string", description: "Substring matched against description and bank_ref" },
            limit:     { type: "integer", minimum: 1, maximum: 200, default: 50 }
          },
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        params = {
          start_date: a["date_from"],
          end_date:   a["date_to"],
          transaction_type: a["type"],
          search: a["search"],
          limit:  (a["limit"] || 50)
        }.compact_blank

        result = ::Transactions::QueryService.new(user, params).call
        items = result[:items].includes(:linked_account).map do |t|
          {
            id: t.id, date: t.date.to_s, type: t.transaction_type,
            amount: fmt_amount(t.amount),
            description: t.description, bank_ref: t.bank_ref, tags: t.tags,
            linked_account: linked_account_label(t)
          }
        end
        {
          total: result[:total],
          returned: items.size,
          items: items
        }
      end

      private

      def linked_account_label(t)
        case t.linked_account_type
        when "Account"     then "account: #{t.linked_account&.nickname}"
        when "TermAccount" then "term_account: #{t.linked_account&.account_number || t.linked_account&.account_type&.upcase}"
        else nil
        end
      end
    end
  end
end
