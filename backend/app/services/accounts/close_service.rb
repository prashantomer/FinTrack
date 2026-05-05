module Accounts
  class CloseService
    class Error < StandardError; end

    def initialize(account, params)
      @account = account
      @params  = params.to_h.symbolize_keys
    end

    def call
      raise Error, "Account '#{@account.nickname}' is already closed" if @account.closed?

      @account.update!(
        closed_date:   @params[:closed_date],
        closed_amount: @params[:closed_amount]
      )
      @account
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
