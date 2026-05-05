module Api
  module V1
    class TermAccountsController < ApplicationController
      before_action :set_term_account, only: [ :show, :close, :audit_logs ]

      def index
        render_success(data: current_user.term_accounts.includes(parent_account: :bank).order(created_at: :desc))
      end

      def show
        render_success(data: @term_account)
      end

      def create
        result = TermAccounts::CreateService.new(current_user, term_account_params).call
        result = current_user.term_accounts.includes(parent_account: :bank).find(result.id)
        render_created(data: result)
      rescue TermAccounts::CreateService::Error => e
        render_error(message: e.message)
      end

      def close
        result = TermAccounts::CloseService.new(@term_account, close_params).call
        render_success(data: result)
      rescue TermAccounts::CloseService::Error => e
        render_error(message: e.message)
      end

      def audit_logs
        audits = Audited::Audit.where(auditable_type: "TermAccount", auditable_id: @term_account.id)
                               .order(created_at: :desc)
        render_success(data: audits.map { |a| audit_log_json(a) })
      end

      private

      def set_term_account
        @term_account = current_user.term_accounts.includes(parent_account: :bank).find(params[:id])
      end

      def term_account_params
        p = params.permit(:account_type, :type, :account_number, :amount, :interest_rate,
                          :tenure_days, :open_date, :maturity_amount, :notes,
                          :parent_account_id)
        p[:account_type] ||= p.delete(:type)
        p
      end

      def close_params
        params.permit(:closed_date, :closed_amount)
      end

      def audit_log_json(audit)
        raw = audit.audited_changes["balance"]
        old_val, new_val = raw.is_a?(Array) ? [ raw[0], raw[1] ] : [ nil, raw ]
        {
          id:          audit.id,
          table_name:  "term_account",
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
