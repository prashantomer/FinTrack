module Imports
  # Adapters that translate a parsed bank-statement row (CSV or Excel) into
  # the canonical hash shape Imports::ProcessTransactionRowService expects:
  #   { date:, amount:, type:, description:, tags:, bank_ref:,
  #     linked_account_nickname: }
  #
  # Detection happens once per file via .for_headers(headers). Per-row
  # mapping is delegated to .transform(row, batch:). The Default adapter
  # is a pass-through for the canonical CSV schema documented in the
  # template service; bank-specific adapters do the heavy lifting.
  module TransactionFormatAdapters
    # Header signature for ICICI Bank's "Detailed Statement" Excel export
    # (produced by their JasperReports backend). Stable across years.
    ICICI_SIGNATURE = %i[s_no transaction_date transaction_remarks].freeze

    def self.for_headers(headers)
      symbols = headers.compact.map { |h| h.is_a?(Symbol) ? h : h.to_s.strip.downcase.to_sym }
      return Icici if (ICICI_SIGNATURE - symbols).empty?
      Default
    end

    # Canonical CSV format — fields already match the ProcessTransactionRow
    # contract, so transform is a no-op aside from defensive symbolisation.
    module Default
      def self.transform(row, batch: nil)
        h = row.respond_to?(:to_h) ? row.to_h : row
        h.transform_keys { |k| k.to_s.strip.downcase.to_sym }
      end
    end

    # ICICI Bank "Detailed Statement" XLS:
    #   col 2: S No.                       (numeric → data row marker)
    #   col 4: Transaction Date            (DD-MM-YYYY string)
    #   col 6: Transaction Remarks         (free text + UTR/UPI ref)
    #   col 7: Withdrawal Amount(INR)      (string number; "0.00" if credit)
    #   col 8: Deposit Amount(INR)         (string number; "0.00" if debit)
    #
    # ICICI does not expose a dedicated bank reference column — the UTR /
    # UPI / NEFT ref lives inside the remarks. We store the full trimmed
    # remarks string as `bank_ref` (prefixed with the bank name to avoid
    # collisions with other banks' refs); the dedup ladder then catches
    # re-uploads of the same statement.
    module Icici
      # bank_ref is varchar(100). Reserve 6 for the "ICICI:" prefix, leaving
      # 94 chars from the remark — enough to keep the protocol code + ref
      # number unique while staying within the column.
      BANK_REF_PREFIX     = "ICICI:".freeze
      BANK_REF_BODY_LIMIT = 94

      def self.transform(row, batch: nil)
        h = row.respond_to?(:to_h) ? row.to_h : row

        withdrawal = parse_amount(h[:withdrawal_amount_inr])
        deposit    = parse_amount(h[:deposit_amount_inr])

        if withdrawal > 0
          type   = "debit"
          amount = withdrawal
        elsif deposit > 0
          type   = "credit"
          amount = deposit
        else
          raise "ICICI row has zero withdrawal AND deposit (row may be a balance / non-data line)"
        end

        remarks = h[:transaction_remarks].to_s.strip
        raise "ICICI row missing Transaction Remarks" if remarks.empty?

        {
          date:        h[:transaction_date].to_s.strip,
          amount:      amount.to_s,
          type:        type,
          description: remarks,
          tags:        nil,
          bank_ref:    "#{BANK_REF_PREFIX}#{remarks[0, BANK_REF_BODY_LIMIT]}",
          # ICICI rows don't carry per-row account info — the batch-level
          # linked_account chosen at upload time is authoritative.
          linked_account_nickname: nil,
          # ICICI's Balance(INR) column — informational only. The job
          # captures the LAST row's value as the batch's expected balance,
          # and reconciles against the post-import account.balance per the
          # batch's on_balance_mismatch setting (ask / adjust / fail).
          balance_after: parse_amount(h[:balance_inr])
        }
      end

      def self.parse_amount(raw)
        raw.to_s.strip.delete(",").to_f
      end
    end
  end
end
