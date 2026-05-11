module TermAccounts
  class CloseService
    class Error < StandardError; end

    def initialize(term_account, params)
      @ta     = term_account
      @params = params.to_h.symbolize_keys
    end

    def call
      raise Error, "Term account is already closed" if @ta.closed?

      ActiveRecord::Base.transaction do
        closed_amount = @params[:closed_amount].to_f
        closed_date   = Date.parse(@params[:closed_date].to_s)

        @ta.close!(closed_date: closed_date, closed_amount: closed_amount)

        # The maturity Transaction's after_create callback runs
        # `apply_balance_delta`, which already credits the parent account.
        # Previously we also called `parent_account.credit!(closed_amount)`
        # explicitly here — that was a duplicate write, so closing an
        # FD/PPF double-credited the parent and produced two audit rows.
        @ta.user.transactions.create!(
          amount:           closed_amount,
          transaction_type: "credit",
          description:      "#{@ta.account_type.upcase} Maturity: #{@ta.account_number}",
          date:             closed_date,
          linked_account:   @ta.parent_account
        )
      end

      @ta
    rescue Account::Error, TermAccount::Error => e
      raise Error, e.message
    end
  end
end
