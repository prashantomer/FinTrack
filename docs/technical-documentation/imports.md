# Imports pipeline

> CSV / XLS / XLSX uploads → parsed → adapter-normalised → row-by-row applied
> → reconciled against the source file's running balance. The user picks a
> policy upfront (`ask` / `adjust` / `fail`) and the wizard handles the
> rest.

## End-to-end flow

```
User uploads file via wizard
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ POST /api/v1/imports                                        │
│ ImportsController#create                                    │
│   - validates extension (.csv / .xls / .xlsx) and size (5MB)│
│   - persists ImportBatch + attaches file (Active Storage)   │
│   - enqueues Imports::ProcessTransactionCsvJob (or invest-  │
│     ments / term_accounts variant)                          │
└────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ Imports::ProcessTransactionCsvJob#perform                   │
│   load_rows(batch) → returns (rows, adapter)                │
│     - branches on file extension (.csv vs .xls/.xlsx)       │
│     - CSV: CSV.parse with headers + symbol converter        │
│     - XLS/XLSX: Imports::TransactionWorkbookReader (roo)    │
│   For each row:                                             │
│     normalised = adapter.transform(raw_row, batch:)         │
│     result     = ProcessTransactionRowService.new(...).call │
│   After all rows: finalize_with_reconciliation!             │
└────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ Reconciliation                                              │
│   expected_balance = last row's balance_after (if adapter   │
│                      is balance-aware; ICICI exposes it)    │
│   gap = account.balance − expected_balance                  │
│   if |gap| < 0.01      → status: completed                  │
│   elsif policy=adjust  → AdjustBalanceService → completed   │
│   elsif policy=fail    → AbortBatchService → failed         │
│   else (ask)           → status: needs_reconciliation       │
│                          UI shows the gap + Adjust/Abort    │
│                          buttons; resolve via              │
│                          POST /imports/:id/resolve          │
└────────────────────────────────────────────────────────────┘
```

## The adapter pattern

`Imports::TransactionFormatAdapters` (and `InvestmentFormatAdapters` for
the investment importer) translates a source-specific row into the
canonical hash that the row service expects.

### Contract

```ruby
module Imports::TransactionFormatAdapters
  ICICI_SIGNATURE = %i[s_no transaction_date transaction_remarks].freeze

  # Detection runs once per file from the parsed headers.
  def self.for_headers(headers)
    symbols = headers.compact.map { |h| h.to_s.strip.downcase.to_sym }
    return Icici if (ICICI_SIGNATURE - symbols).empty?
    Default
  end

  # Each adapter responds to .transform(row, batch:) → canonical hash.
  module Icici
    def self.transform(row, batch: nil)
      h = row.respond_to?(:to_h) ? row.to_h : row
      # ... map columns to canonical fields ...
      {
        date:        h[:transaction_date].to_s.strip,
        amount:      ...,
        type:        ...,            # "credit" or "debit"
        description: ...,
        bank_ref:    "ICICI:#{remarks[0, 94]}",
        tags:        nil,
        linked_account_nickname: nil,  # batch-level for ICICI
        balance_after: parse_amount(h[:balance_inr])  # informational
      }
    end
  end

  module Default
    def self.transform(row, batch: nil)
      row.to_h.transform_keys { |k| k.to_s.strip.downcase.to_sym }
    end
  end
end
```

### How to add a new bank

1. Add a constant signature: `HDFC_SIGNATURE = %i[txn_date narration deposit withdrawal]`.
2. Add a module: `module Hdfc; def self.transform(row, batch:); ...; end; end`.
3. Add a branch to `for_headers` that returns `Hdfc` when the signature matches.
4. (Optional) Store the source running balance in `balance_after` if the
   bank's export has it — the job will use it for reconciliation.

That's the whole surface. No new tables, no new controller branches.

## Workbook reader

`Imports::TransactionWorkbookReader` (`backend/app/services/imports/transaction_workbook_reader.rb`)
wraps `roo` + `roo-xls` to handle `.xls` (binary, via roo-xls) and `.xlsx`
(via roo).

What it does:
1. Opens the workbook.
2. **Auto-locates the header row** by scanning for known markers
   (`"S No."`, `"Sl No."`, etc.) — bank statements have N rows of
   metadata above the table.
3. Extracts metadata rows into `reader.meta` (account number, statement
   period — useful for sanity checks).
4. Yields each data row as `header_symbol → value` hashes.
5. **Merges continuation rows** — banks sometimes wrap a long remark onto a
   second sheet row. A row whose S No. is empty but whose remarks column has
   content gets folded into the previous data row.
6. Stops at footer markers (`"LEGENDS"`, `"Note:"`).

The reader is bank-agnostic; only the adapter knows what a "remark" means.

## Dedup ladder

`Imports::ProcessTransactionRowService#find_duplicate`:

1. If the row's `bank_ref` is set, look up `user.transactions.find_by(bank_ref:)`.
   - **If present, that's the answer.** Do NOT fall back to structural match.
     ICICI emits a unique bank_ref per row, but multiple legitimate UPIs can
     share `(date, amount, type, account)`. Falling back would collapse
     legitimate repeats.
2. Otherwise (canonical CSV with no bank_ref), structural match on
   `(date, amount, type, linked_account_type, linked_account_id)`.

Investment imports have their own ladder (`bank_ref` → `(order_id, purchase_date)`
→ structural). Term-account imports use `(account_type, account_number)` → structural.

Duplicate rows write a `:skipped` ImportRecord with a `notes` like
`"Duplicate of Transaction #842 (bank_ref ICICI:NEFT-HDFCH...)"` and bump
`batch.duplicate_rows`. Re-uploading the same statement is N/N duplicates,
not an error.

## Reconciliation policy

Set on `ImportBatch.on_balance_mismatch` at create time (Step 2 of the wizard):

| Value      | What happens when the source file's last balance ≠ `account.balance` after import |
|------------|-----------------------------------------------------------------------------------|
| `ask` (default) | Batch enters `needs_reconciliation` status. UI shows the gap + two buttons. User POSTs to `/imports/:id/resolve` with `action_choice: "adjust"` or `"abort"`. |
| `adjust`   | Silently creates a balancing Transaction (tagged `"adjustment"`, description `"Import reconciliation (batch #N)"`) so balance lands on `expected_balance`. |
| `fail`     | `Imports::AbortBatchService` reverses every txn the batch created (audit-trail: `"revert:txn_<id>"` per row) and marks the batch `:failed`. |

The reconciliation only runs when the adapter populated `balance_after` on
at least one row. Canonical CSV imports have no expected balance and
finalise unconditionally.

## Frontend wizard (`ImportWizard.tsx`)

5 steps:

| Step | What it does |
|------|--------------|
| 1. Select type | Investments / Transactions / Term accounts |
| 2. Context | For transactions: pick "Default Linked Account" (required for xls — they don't carry per-row account info), pick "Balance reconciliation" policy (ask/adjust/fail) |
| 3. Template | Shows the canonical CSV column reference + download-template button. XLS/XLSX skip this. |
| 4. Upload | Drop zone; csv / xls / xlsx accepted; preview only for CSV |
| 5. Processing | Polls `useImport(id)` every 1.5s. Renders progress bar; on `needs_reconciliation`, shows an amber prompt with "Create adjustment" / "Abort" buttons |

State machine on the frontend hook (`useImport`):

```ts
status === "pending" | "processing"       → keep polling
status === "completed" | "failed"         → stop polling, show summary
status === "needs_reconciliation"         → stop polling, show prompt + resolve buttons
```

## Sample patterns

### Canonical transaction CSV

```
date,amount,type,linked_account_nickname,description,tags,bank_ref
2026-04-01,1000.00,credit,HDFC Primary,Salary,salary,REF-001
2026-04-02,250.00,debit,HDFC Primary,Coffee,,
```

### ICICI xls (auto-detected)

```
DETAILED STATEMENT
...
Account Number    144101510503 ( INR )  - PRASHANT OMER
Transaction Date from  01-04-2026  to  11-05-2026
...
Transactions List
S No. | Value Date | Transaction Date | Cheque Number | Transaction Remarks | Withdrawal Amount(INR) | Deposit Amount(INR) | Balance(INR)
1     | 31-03-2026 | 01-04-2026       |               | NEFT-HDFCH...       | 0.00                    | 200000.00            | 233898.19
2     | 01-04-2026 | 01-04-2026       |               | BIL/INFT/...        | 3335.32                 | 0.00                 | 230562.87
...
```

Auto-detected by `for_headers` matching `%i[s_no transaction_date transaction_remarks]`.
`bank_ref` is synthesised from the remarks (`"ICICI:NEFT-HDFCH..."`, truncated
to fit varchar(100)). The Balance(INR) column drives reconciliation.

---

Last reviewed: 2026-05-11
