# Audit & Balance Integrity

> The contract: for every change to an `Account.balance` or
> `TermAccount.balance`, exactly one `Audited::Audit` row exists, and its
> `comment` field references the cause. The system tries hard to keep this
> true. This doc enumerates every code path that mutates a balance, what it
> stamps on the audit row, and how to fix things if they drift.

## The audited gem in one paragraph

`audited` (v5.4) hooks AR callbacks (`after_create`, `after_update`,
`after_destroy`) on models that declare `audited only: [:balance]`. When
the balance column changes via a callback-firing path (`update!`,
`save!`), it inserts one row into the `audits` table with the diff in a
JSONB column. **The gem does not see SQL-level writes** — `update_columns`,
`update_all`, `increment!`, `decrement!`, and raw `connection.execute` all
bypass it silently.

Two table-level configs on the gem use a thread-local:
- `Audited.audit_class.as_user(user) { ... }` — sets the audit row's
  `user_id`. Used by every callback path so attribution is correct.
- `model.audit_comment = "txn:42"` — sets the `comment` column on the
  next produced audit row.

## Audited models

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  audited only: [ :balance ]
  # ...
end

# app/models/term_account.rb
class TermAccount < ApplicationRecord
  audited only: [ :balance ]
  # ...
end
```

`balance` is the only field audited on either. We deliberately don't track
`nickname`, `account_number`, `open_date`, etc. — they don't matter for
financial integrity and would dilute the audit table.

## Every balance-mutating path

| Path | File | `update!`? | Audit `comment` |
|------|------|------------|------------------|
| `Transaction#apply_balance_delta` (after_create) | `app/models/transaction.rb` | ✓ | `"txn:<txn_id>"` |
| `Transaction#reverse_balance_delta` (before_destroy) | `app/models/transaction.rb` | ✓ | `"revert:txn_<txn_id>"` |
| `TermAccount#close!` | `app/models/term_account.rb` | ✓ | `"close:term_account_<id>"` |
| `TermAccount#deposit!` | `app/models/term_account.rb` | ✓ | (none — see notes) |
| `Account#credit!(amount, source:)` | `app/models/account.rb` | ✓ | the `source:` kwarg |
| `Account#debit!(amount, source:)`  | `app/models/account.rb` | ✓ | the `source:` kwarg |
| `Cleanup::ExecuteService#reset_balances!` | `app/services/cleanup/execute_service.rb` | ✗ (`update_all`) | bypasses audit on purpose — see notes |
| `accounts:recompute_balances` rake | `lib/tasks/accounts.rake` | ✗ (`update_columns`) | bypasses; follow up with `audits:backfill` |
| `audits:backfill` rake | `lib/tasks/audits.rake` | n/a | directly inserts Audited::Audit rows with `"txn:<id>"` or `"carryover"` |

### Notes on the bypass paths

**`Cleanup::ExecuteService#reset_balances!`** uses `update_all` because
cleanup is meant to be a quiet operation, not produce a fresh audit trail.
The matching audit sweep (one of the cleanup sectors) already removed the
pre-existing rows. Running cleanup followed by `audits:backfill` rebuilds
a clean per-txn timeline.

**`accounts:recompute_balances`** uses `update_columns` because it's a
reconciliation tool, not a real-world event. The followup step is always
`audits:backfill` to rebuild the audit timeline against the corrected
balance.

**`TermAccount#deposit!`** doesn't stamp a comment today. It's used only
by tests and one branch of `TermAccount` creation; if a real caller appears,
add a `source:` kwarg like Account#credit!/debit!.

## The Transaction lifecycle (canonical balance writer)

```ruby
Transaction.create!  →  after_create :apply_balance_delta

  return unless linked_account.present?
  return if linked_account.is_a?(TermAccount) && linked_account.fd?

  delta = credit? ? amount : -amount
  Audited.audit_class.as_user(user) do
    linked_account.audit_comment = "txn:#{id}"
    linked_account.update!(balance: linked_account.balance + delta)
  end
```

```ruby
Transaction#destroy  →  before_destroy :reverse_balance_delta

  # Mirror of apply, with sign flipped.
  delta = credit? ? -amount.to_f : amount.to_f
  Audited.audit_class.as_user(user) do
    linked_account.audit_comment = "revert:txn_#{id}"
    linked_account.update!(balance: linked_account.balance.to_f + delta)
  end
```

This pair keeps the invariant `account.balance == sum(signed deltas of
A's active transactions)` for every Account A — provided every create and
destroy goes through these callbacks. `delete_all` skips them; whenever
you use it, follow up with `accounts:recompute_balances` or take
responsibility for the reversal yourself.

## FD term accounts skip on purpose

```ruby
return if linked_account.is_a?(TermAccount) && linked_account.fd?
```

An FD's balance is principal + interest computed at maturity. It doesn't
respond to per-transaction deltas. The matching paired transactions
(savings-debit + FD-credit) are created at FD-creation time, but only the
savings-debit's `apply_balance_delta` runs; the FD-credit's would have
been a no-op. We short-circuit explicitly so the intent is clear.

PPF, by contrast, accumulates from per-deposit transactions and *does*
participate in `apply_balance_delta`.

## Reading the audit log

```ruby
GET /api/v1/accounts/:id/audit-logs

# Returns each audit row with the linked Transaction (or null), where the
# link is resolved by parsing the `comment` field:
#
#   audit.comment matches /\Atxn:(\d+)\z/  → embed Transaction row
#   audit.comment == "carryover"           → opening / backfill carry-over
#   audit.comment matches /\Aclose:.../    → close event
#   audit.comment matches /\Arevert:.../   → destroy reversal
#   audit.comment.blank?                   → "Balance update" (anonymous)
```

The frontend `AuditLogSidebar.tsx` renders each row with an icon based on
the delta direction (credit = up arrow, debit = down arrow, initial create
= plus-circle) and labels the action from the embedded transaction's
description when available, falling back to a generic "Balance update".

## Recovery recipes

### Drift between transactions and balance

```bash
bin/rails accounts:recompute_balances DRY_RUN=1   # see what's off
bin/rails accounts:recompute_balances             # fix it
bin/rails audits:backfill                          # rebuild the timeline
```

The recompute task sets `account.balance = sum(signed deltas of active txns)`.
The backfill rake then walks the txns in chronological order and inserts one
audit row per — followed by a synthetic `"carryover"` row if there's
unexplained delta the txn history doesn't account for (rare; means someone
mutated balance directly).

### Missing audit row after a known balance change

The change went through a path that bypassed the gem. The two known
bypassers are documented above (`update_columns` and `update_all`).
Re-run `audits:backfill` to rebuild from the txn history; you'll lose
the bypass row but gain a clean per-txn timeline.

### Audit row with no comment

Means the path that wrote the balance didn't set `audit_comment`. Find
the path (search for `update!(balance:` or `update!(...balance...)`
without an enclosing `as_user`/`audit_comment` block) and add the stamp.

## Why we don't use a database trigger

Auditing in DB triggers would catch every write (no callback bypass), but:

1. It can't see Rails-level context (which user, which transaction).
2. It double-fires when AR also writes via `update!`, creating duplicates.
3. We control every code path that writes balance — there's no external
   ETL or third-party app touching the DB. Application-level enforcement
   is sufficient and visible in code review.

If we ever expose the DB to a second writer (analytics dump-loaders, etc.),
revisit this decision and add a trigger-based safety net.

---

Last reviewed: 2026-05-11
