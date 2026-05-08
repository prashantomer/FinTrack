module Assistants
  module Tools
    class QueryDashboard < Base
      def name; "query_dashboard"; end
      def description
        "Return a summary of the user's overall financial position: net worth, cash balance across accounts, FD/PPF balance, this-month and previous-month inbound/outbound flows, and portfolio holdings grouped by investment type."
      end
      def input_schema
        { type: "object", properties: {}, additionalProperties: false }
      end

      def call(_args)
        ::Reports::DashboardService.new(user).call
      end
    end
  end
end
