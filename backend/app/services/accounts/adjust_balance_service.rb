module Accounts
  # User-driven balance correction: rather than writing `account.balance`
  # directly (which would bypass the transaction ledger), we materialise an
  # adjustment Transaction that brings the account to the requested state.
  # The transaction flows through the normal `apply_balance_delta` callback,
  # so the audit log + balance update happen in one place.
  #
  # The Transaction's amount = | target_balance - current_balance |, with
  # type = credit if the balance needs to go up, debit if down.
  #
  # Used by:
  #   - The "Adjust balance" UI on the Accounts page (after opening, when
  #     the user wants to reconcile to the bank's actual balance).
  #   - The "set opening balance" action when the user wants to record a
  #     starting balance on or after the account's open_date.
  class AdjustBalanceService
    class Error < StandardError; end

    DEFAULT_DESCRIPTION = "Balance adjustment".freeze

    def initialize(user, account, target_balance:, date: Date.current, description: nil)
      @user           = user
      @account        = account
      @target_balance = target_balance
      @date           = date.is_a?(Date) ? date : Date.parse(date.to_s)
      @description    = description.presence || DEFAULT_DESCRIPTION
    end

    def call
      raise Error, "Account is closed" if @account.closed?
      raise Error, "Date is before account open date (#{@account.open_date})" if @date < @account.open_date

      delta = (@target_balance.to_f - @account.balance.to_f).round(2)
      raise Error, "Target balance equals current balance — no adjustment needed" if delta.abs < 0.01

      Transaction.create!(
        user:                @user,
        source:              "manual",
        amount:              delta.abs,
        transaction_type:    (delta > 0 ? "credit" : "debit"),
        date:                @date,
        description:         @description,
        # The "adjustment" tag distinguishes this row from a real-world txn
        # when filtering — useful when reconciling against the bank statement.
        tags:                [ "adjustment" ],
        linked_account_type: "Account",
        linked_account_id:   @account.id
      )
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
