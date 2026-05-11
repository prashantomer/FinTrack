namespace :audits do
  desc <<~DESC
    Backfill `audits` rows for every historical Transaction balance change.

    Why: balance updates were previously written via `increment!`, which
    bypasses ActiveRecord callbacks and therefore the `audited` gem. As a
    result the audits table only ever held one `create` row per account
    (balance: 0). Every subsequent change is invisible in the Balance
    History sidebar.

    This task replays each user's transactions in chronological order
    (date asc, id asc — same ordering as Transactions::QueryService), and
    INSERTs one synthetic `update` audit per transaction that touches an
    Account or PPF TermAccount balance. FD term accounts are skipped on
    purpose (their balance is principal-based, not running).

    Idempotent: any existing `comment LIKE 'txn:%'` rows are wiped first,
    so re-running just rebuilds. The original `create` audit rows ("Account
    opened — ₹0") stay untouched.

    No account balances are modified — this is audit-table-only.

      $ bin/rails audits:backfill              # all users
      $ bin/rails audits:backfill USER_ID=42   # one user
      $ bin/rails audits:backfill DRY_RUN=1    # report only
  DESC
  task backfill: :environment do
    user_scope = User.all
    user_scope = user_scope.where(id: ENV["USER_ID"]) if ENV["USER_ID"]
    dry_run    = ENV["DRY_RUN"].present?

    total_inserted = 0
    total_wiped    = 0

    user_scope.find_each do |user|
      txns = user.transactions
                 .where(is_active: true)
                 .where.not(linked_account_id: nil)
                 .order(:date, :id)
                 .to_a

      next if txns.empty?

      # Group by linked account so the running-balance walk is per-account
      # and matches how `apply_balance_delta` would have written audits at
      # the time the transaction was created.
      by_account = txns.group_by { |t| [ t.linked_account_type, t.linked_account_id ] }

      by_account.each do |(account_type, account_id), account_txns|
        next unless account_type == "Account" || account_type == "TermAccount"
        # FD balances aren't tracked as running totals — skip.
        if account_type == "TermAccount"
          ta = TermAccount.find_by(id: account_id)
          next if ta.nil? || ta.fd?
        end

        wiped = Audited::Audit.where(
          auditable_type: account_type,
          auditable_id:   account_id
        ).where("comment LIKE 'txn:%' OR comment = 'carryover'").delete_all
        total_wiped += wiped

        # First pass: replay txns to figure out where they land. If the
        # replay doesn't match the actual balance in DB, the difference is
        # pre-existing drift (destroyed txns that didn't reverse balance,
        # console writes, etc.). Insert a single "carryover" audit row to
        # close the gap and keep the timeline honest.
        actual_balance = account_type == "Account" ?
          Account.find(account_id).balance.to_f :
          TermAccount.find(account_id).balance.to_f

        sum_of_deltas = account_txns.sum { |t| (t.credit? ? t.amount.to_f : -t.amount.to_f) }
        carryover     = (actual_balance - sum_of_deltas).round(2)

        running = 0.0
        first_txn_date = account_txns.first.date

        if carryover.abs >= 0.01
          unless dry_run
            Audited::Audit.create!(
              auditable_type:  account_type,
              auditable_id:    account_id,
              user_type:       "User",
              user_id:         user.id,
              action:          "update",
              audited_changes: { "balance" => [ 0.0, carryover ] },
              comment:         "carryover",
              created_at:      (first_txn_date.is_a?(Date) ? first_txn_date.to_time : first_txn_date) - 1.second
            )
            total_inserted += 1
          end
          running = carryover
        end

        account_txns.each do |t|
          delta = t.credit? ? t.amount.to_f : -t.amount.to_f
          old_bal = running
          new_bal = (running + delta).round(2)
          running = new_bal

          next if dry_run

          Audited::Audit.create!(
            auditable_type:  account_type,
            auditable_id:    account_id,
            user_type:       "User",
            user_id:         user.id,
            action:          "update",
            audited_changes: { "balance" => [ old_bal, new_bal ] },
            comment:         "txn:#{t.id}",
            # Backdate the audit to the transaction's date so the timeline
            # matches the user's mental model (when the money moved, not
            # when we ran the backfill).
            created_at:      t.date.is_a?(Date) ? t.date.to_time : t.date
          )
          total_inserted += 1
        end
      end

      puts "user ##{user.id} (#{user.email}): #{by_account.size} accounts, #{txns.size} txns"
    end

    if dry_run
      puts "[DRY RUN] would wipe #{total_wiped}, would insert ~#{user_scope.joins(:transactions).count}"
    else
      puts "wiped #{total_wiped} old synthetic audits, inserted #{total_inserted} backfilled audits"
    end
  end
end
