module Cleanup
  # Runs the cleanup. Wraps everything in a single ActiveRecord transaction
  # so a failure mid-wipe rolls every sector back. Order matches users:wipe
  # (children before parents) so foreign-key constraints don't trip.
  #
  # Optional post-step: `reset_balances` — when truthy, sets every Account
  # the user owns to balance=0 and every PPF TermAccount to 0 via the
  # normal `update_columns` path so we don't sprinkle audit rows for a
  # cleanup operation (the matching audit sweep already removed them).
  class ExecuteService
    DELETE_ORDER = %w[
      assistant_messages import_batches account_audits holdings
      transactions investments user_instruments term_accounts
      accounts platform_accounts
    ].freeze

    def initialize(user, config)
      @user    = user
      @config  = (config || {}).with_indifferent_access
      @builder = ScopeBuilder.new(user, @config)
    end

    def call
      scopes  = @builder.scopes
      deleted = Hash.new(0)

      ActiveRecord::Base.transaction do
        # Iterate in dependency-safe order; skip sectors the user didn't
        # opt in to.
        DELETE_ORDER.each do |sector|
          scope = scopes[sector]
          next if scope.nil?
          deleted[sector] = delete_for(sector, scope)
        end

        reset_balances! if @config[:reset_balances]
      end

      { deleted: deleted, total: deleted.values.sum }
    end

    private

    def delete_for(sector, scope)
      case sector
      when "import_batches"
        # destroy_all so ActiveStorage blobs are purged and import_records cascade.
        scope.destroy_all.size
      else
        scope.delete_all
      end
    end

    # Reset balances on every Account + PPF TermAccount that survives the
    # cleanup. FD term-account balances are principal-based and stay put.
    # Bypasses the `audited` callback intentionally — cleanup is meant to
    # be a quiet operation, not produce a fresh audit trail.
    def reset_balances!
      @user.accounts.update_all(balance: 0)
      @user.term_accounts.where(account_type: "ppf").update_all(balance: 0)
    end
  end
end
