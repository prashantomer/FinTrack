module Api
  module V1
    class AccountsController < ApplicationController
      before_action :set_account, only: [ :show, :update, :destroy, :close, :audit_logs ]

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
        render_success(data: audits.map { |a| audit_log_json(a) })
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

      def audit_log_json(audit)
        raw = audit.audited_changes["balance"]
        old_val, new_val = raw.is_a?(Array) ? [ raw[0], raw[1] ] : [ nil, raw ]
        {
          id:          audit.id,
          table_name:  "account",
          record_id:   audit.auditable_id,
          column_name: "balance",
          old_value:   old_val&.to_s,
          new_value:   new_val&.to_s,
          changed_at:  audit.created_at,
          transaction: nil
        }
      end
    end
  end
end
