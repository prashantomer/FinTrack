module Api
  module V1
    class TransactionsController < ApplicationController
      def index
        txns = Transactions::QueryService.new(current_user, query_params).call
        render_success(
          data:      txns[:items],
          meta_data: { total: txns[:total], next_cursor: txns[:next_cursor] }
        )
      end

      def create
        result = Transactions::CreateService.new(current_user, transaction_params).call
        render_created(data: result)
      rescue Transactions::CreateService::Error => e
        render_error(message: e.message)
      end

      private

      def query_params
        p = params.permit(:transaction_type, :type, :start_date, :end_date, :cursor, :limit,
                          :linked_account_type, :linked_account_id, :search)
        p[:transaction_type] ||= p.delete(:type)
        p[:linked_account_type] = classify_linked_type(p[:linked_account_type])
        p
      end

      def transaction_params
        p = params.permit(:amount, :transaction_type, :type, :description, :date,
                          :linked_account_type, :linked_account_id,
                          :instrument_id, :bank_ref, tags: [])
        p[:transaction_type] ||= p.delete(:type)
        p[:linked_account_type] = classify_linked_type(p[:linked_account_type])
        p
      end

      def classify_linked_type(value)
        return value if value.blank?
        value.classify
      end
    end
  end
end
