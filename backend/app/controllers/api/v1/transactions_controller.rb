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

      # Manual transactions are editable but only on description + tags. Amount
      # and type would silently desync the linked account balance (we apply the
      # delta in after_create and don't reverse on update), so structural
      # corrections still go through the rake task. Imported rows are frozen.
      def update
        txn = current_user.transactions.find(params[:id])
        unless txn.editable?
          return render_error(message: "Imported transactions cannot be edited", status: :forbidden)
        end
        txn.update!(editable_transaction_params)
        render_success(data: txn)
      end

      private

      def query_params
        p = params.permit(:transaction_type, :type, :start_date, :end_date, :date_from, :date_to,
                          :cursor, :limit, :page, :page_size,
                          :linked_account_type, :linked_account_id, :search,
                          :source, :sort_by, :sort_dir)
        p[:transaction_type] ||= p.delete(:type)
        # Frontend mirrors the investments page and sends date_from/date_to;
        # the service still reads start_date/end_date for back-compat.
        p[:start_date] ||= p.delete(:date_from)
        p[:end_date]   ||= p.delete(:date_to)
        # Page-based pagination → translate to cursor/limit. Without this the
        # service silently kept returning page 1 even when the UI asked for
        # page 2+, since it only ever reads `:cursor` and `:limit`.
        if p[:page].present? || p[:page_size].present?
          page_size = p.delete(:page_size).to_i.nonzero? || 50
          page_size = page_size.clamp(1, 200)
          page      = p.delete(:page).to_i.nonzero? || 1
          page      = page.clamp(1, 10_000)
          p[:limit]  = page_size
          p[:cursor] = (page - 1) * page_size
        end
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

      def editable_transaction_params
        params.permit(:description, tags: [])
      end

      def classify_linked_type(value)
        return value if value.blank?
        value.classify
      end
    end
  end
end
