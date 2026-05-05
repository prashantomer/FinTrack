module Transactions
  class CreateService
    class Error < StandardError; end

    def initialize(user, params)
      @user   = user
      @params = params
    end

    def call
      txn = @user.transactions.build(@params)
      txn.save!
      txn
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    rescue RuntimeError => e
      raise Error, e.message
    end
  end
end
