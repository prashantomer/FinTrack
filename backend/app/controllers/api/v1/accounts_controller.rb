module Api
  module V1
    class AccountsController < ApplicationController
      before_action :set_account, only: [ :show, :update, :destroy, :close, :audit_logs, :adjust_balance ]

      def index
        render_success(data: current_user.accounts.includes(:bank).order(:nickname))
      end

      def show
        render_success(data: @account)
      end

      def create
        account = current_user.accounts.build(account_params)
        if account.save
          render_created(data: account)
        else
          render_error(message: "Validation failed", errors: account.errors.to_hash)
        end
      end

      def update
        if @account.update(account_params)
          render_success(data: @account)
        else
          render_error(message: "Validation failed", errors: @account.errors.to_hash)
        end
      end

      def destroy
        @account.destroy
        head :no_content
      end

      def close
        result = Accounts::CloseService.new(@account, close_params).call
        render_success(data: result)
      rescue Accounts::CloseService::Error => e
        render_error(message: e.message)
      end

      def audit_logs
        audits = Audited::Audit.where(auditable_type: "Account", auditable_id: @account.id)
                               .order(created_at: :desc)
        # Bulk-load the transactions referenced by audit_comment ("txn:<id>")
        # in one query so the controller stays O(audits + 1) instead of N+1.
        txn_ids = audits.map { |a| a.comment.to_s[/\Atxn:(\d+)\z/, 1]&.to_i }.compact.uniq
        txns_by_id = current_user.transactions.where(id: txn_ids).index_by(&:id)
        render_success(data: audits.map { |a| audit_log_json(a, txns_by_id) })
      end

      # POST /api/v1/accounts/:id/adjust-balance
      # Body: { target_balance:, date?, description? }
      # Creates an adjustment Transaction that brings the account to
      # `target_balance`. The transaction is dated `date` (default today,
      # must be >= account.open_date). Bringing the account to a starting
      # state after creation uses this same endpoint.
      def adjust_balance
        txn = Accounts::AdjustBalanceService.new(
          current_user,
          @account,
          target_balance: params.require(:target_balance),
          date:           params[:date].presence || Date.current,
          description:    params[:description]
        ).call
        render_created(data: { transaction_id: txn.id, account: @account.reload })
      rescue Accounts::AdjustBalanceService::Error => e
        render_error(message: e.message)
      end

      private

      def set_account
        @account = current_user.accounts.includes(:bank).find(params[:id])
      end

      def account_params
        params.permit(:nickname, :account_type, :bank_id, :account_number, :open_date)
      end

      def close_params
        params.permit(:closed_date, :closed_amount)
      end

      def audit_log_json(audit, txns_by_id = {})
        raw = audit.audited_changes["balance"]
        old_val, new_val = raw.is_a?(Array) ? [ raw[0], raw[1] ] : [ nil, raw ]

        txn_id = audit.comment.to_s[/\Atxn:(\d+)\z/, 1]&.to_i
        txn    = txn_id && txns_by_id[txn_id]
        txn_json = txn && {
          id:          txn.id,
          date:        txn.date,
          amount:      txn.amount.to_f,
          type:        txn.transaction_type,
          description: txn.description,
          bank_ref:    txn.bank_ref
        }

        {
          id:          audit.id,
          table_name:  "account",
          record_id:   audit.auditable_id,
          column_name: "balance",
          old_value:   old_val&.to_s,
          new_value:   new_val&.to_s,
          changed_at:  audit.created_at,
          # 'carryover' is a synthetic row inserted by the backfill task to
          # account for pre-fix drift between transaction history and the
          # actual balance. The UI surfaces it as "Opening / carry-over"
          # with no linked transaction.
          comment:     audit.comment,
          transaction: txn_json
        }
      end
    end
  end
end
