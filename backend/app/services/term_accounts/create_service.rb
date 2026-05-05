module TermAccounts
  class CreateService
    class Error < StandardError; end

    def initialize(user, params)
      @user   = user
      @params = params.to_h.symbolize_keys
    end

    def call
      parent = @user.accounts.find(@params[:parent_account_id])
      raise Error, "Parent account '#{parent.nickname}' is closed" if parent.closed?

      ActiveRecord::Base.transaction do
        ta = @user.term_accounts.build(@params)
        ta.save!

        # FD only: debit parent savings account and credit term account
        if ta.fd?
          @user.transactions.create!(
            amount:         ta.amount,
            transaction_type: "debit",
            description:    "FD Opening: #{ta.account_number}",
            date:           ta.open_date,
            linked_account: parent
          )
          @user.transactions.create!(
            amount:         ta.amount,
            transaction_type: "credit",
            description:    "FD Opening: #{ta.account_number}",
            date:           ta.open_date,
            linked_account: ta
          )
        end

        ta
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    rescue Account::Error, TermAccount::Error => e
      raise Error, e.message
    end
  end
end
