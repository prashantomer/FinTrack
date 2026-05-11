namespace :accounts do
  desc <<~DESC
    Recompute account balances from the active transaction history.

    For each non-closed Account (and each PPF TermAccount — FDs are
    principal-based so they're skipped), this task sums the signed deltas
    of every `is_active: true` transaction linked to that account and
    overwrites `balance` with that sum.

    Why: balances can drift from the transaction history if rows were
    destroyed without reversing the balance (the Transaction model has
    no before_destroy hook today), or if balance was nudged from the
    console. This task makes the books match the ledger.

    `update_columns` is used on purpose — we're correcting drift, not
    making a "real" balance change, so we skip the `audited` callback
    here. Re-run `bin/rails audits:backfill` afterwards to produce a
    clean per-transaction audit timeline that lands exactly on the
    recomputed balance.

      $ bin/rails accounts:recompute_balances             # all users
      $ bin/rails accounts:recompute_balances USER_ID=2   # one user
      $ bin/rails accounts:recompute_balances DRY_RUN=1   # report only
  DESC
  task recompute_balances: :environment do
    user_scope = User.all
    user_scope = user_scope.where(id: ENV["USER_ID"]) if ENV["USER_ID"]
    dry_run    = ENV["DRY_RUN"].present?

    accounts_updated = 0
    term_accounts_updated = 0
    total_drift = 0.0

    user_scope.find_each do |user|
      user.accounts.open.find_each do |account|
        target = sum_for(user, "Account", account.id)
        drift  = (account.balance.to_f - target).round(2)
        next if drift.abs < 0.01

        puts sprintf("user ##{user.id}  Account##{account.id} %-22s %12.2f → %12.2f  (Δ %+.2f)",
                     account.nickname, account.balance.to_f, target, -drift)
        total_drift += drift

        unless dry_run
          account.update_columns(balance: target)
          accounts_updated += 1
        end
      end

      user.term_accounts.where(is_active: true).find_each do |ta|
        next if ta.fd?  # FDs are principal-based; balance is not derived from transactions
        target = sum_for(user, "TermAccount", ta.id)
        drift  = (ta.balance.to_f - target).round(2)
        next if drift.abs < 0.01

        puts sprintf("user ##{user.id}  TermAccount##{ta.id} %-15s %12.2f → %12.2f  (Δ %+.2f)",
                     "(#{ta.account_type})", ta.balance.to_f, target, -drift)
        total_drift += drift

        unless dry_run
          ta.update_columns(balance: target)
          term_accounts_updated += 1
        end
      end
    end

    puts ""
    if dry_run
      puts "[DRY RUN] total drift discovered: ₹#{total_drift.round(2)}"
    else
      puts "Updated #{accounts_updated} accounts + #{term_accounts_updated} term accounts. " \
           "Total drift absorbed: ₹#{total_drift.round(2)}."
      puts "Re-run `bin/rails audits:backfill` to rebuild the audit timeline " \
           "without the carryover rows."
    end
  end

  # Sum of signed deltas of active transactions linked to (account_type, id).
  def sum_for(user, account_type, account_id)
    user.transactions
        .where(is_active: true, linked_account_type: account_type, linked_account_id: account_id)
        .sum("CASE WHEN transaction_type = 'credit' THEN amount ELSE -amount END")
        .to_f
        .round(2)
  end
end
