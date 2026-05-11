module Imports
  class ProcessTransactionRowService
    DATE_FORMATS = [ "%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y" ].freeze
    DUPLICATE    = :duplicate

    def initialize(batch, row, idx)
      @batch = batch
      @user  = batch.user
      @row   = row
      @idx   = idx
    end

    def call
      date   = parse_date!(@row[:date])
      amount = @row[:amount].to_f
      unless amount > 0
        raise Imports::Error.new("amount must be greater than 0",
                                 code: :amount_invalid,
                                 context: { raw: @row[:amount] })
      end

      type = @row[:type].to_s.strip.downcase
      unless %w[credit debit].include?(type)
        raise Imports::Error.new("type must be 'credit' or 'debit'",
                                 code: :type_invalid,
                                 context: { raw: @row[:type] })
      end

      linked_account = resolve_linked_account
      tags           = parse_tags(@row[:tags])
      bank_ref       = @row[:bank_ref].presence

      if (existing = find_duplicate(date, amount, type, linked_account, bank_ref))
        return register_duplicate(existing)
      end

      txn = Transaction.create!(
        user:                 @user,
        source:               :imported,
        amount:               amount,
        transaction_type:     type,
        date:                 date,
        description:          @row[:description].presence,
        tags:                 tags,
        bank_ref:             bank_ref,
        linked_account_type:  linked_account ? linked_account.class.name : nil,
        linked_account_id:    linked_account&.id
      )

      @batch.import_records.create!(
        importable: txn,
        row_index:  @idx,
        status:     :ok,
        notes:      linked_account ? "Linked to account: #{linked_account.nickname}" : nil
      )
      txn
    end

    private

    def find_duplicate(date, amount, type, linked_account, bank_ref)
      self.class.duplicate_for(
        user:           @user,
        date:           date,
        amount:         amount,
        type:           type,
        linked_account: linked_account,
        bank_ref:       bank_ref,
        batch:          @batch
      )
    end

    # Dedupe ladder — class method so callers other than the row-processor
    # (e.g. the opening-balance seed in ProcessTransactionCsvJob) can ask
    # "would this row be treated as a duplicate?" without instantiating
    # the service or constructing a partial ImportRecord side-effect.
    #
    # The uniqueness key is always the full tuple
    # `(date, amount, type, linked_account, bank_ref)` — bank_ref alone is
    # NOT sufficient. ICICI (and many banks) reuse the same remark string
    # across genuinely distinct sweep / closure / interest entries dated
    # different days for different amounts; collapsing on `bank_ref` alone
    # would drop ~12% of a typical year's statement and leave the account
    # short by the sum of the merged rows.
    #
    # Adding `(date, amount, type)` to the key still catches every real
    # duplicate (a re-uploaded statement matches all four fields exactly)
    # and still distinguishes genuine repeat UPIs (two ₹500 payments to
    # the same merchant on the same day have different UTRs → different
    # bank_refs → no false merge).
    #
    # **`batch:` excludes in-flight rows from this same batch's run.** ICICI
    # ATM cash-withdrawal remarks don't include a transaction sequence
    # number, so two ₹10,000 withdrawals from the same ATM on the same day
    # produce identical `bank_ref` strings (e.g. "ICICI:NFS/MPZ08171/CASH
    # WDL/15-06-23"). With internal-batch rows in the dedup pool, the
    # second withdrawal would collapse against the first one this loop
    # just created — losing a real ₹10k debit and breaking end-balance
    # reconciliation. Filtering to txns that existed BEFORE the batch
    # started keeps both intra-file twins, while still catching re-uploads
    # of a previously-imported statement (those match prior-batch rows).
    def self.duplicate_for(user:, date:, amount:, type:, linked_account:, bank_ref:, batch: nil)
      scope = user.transactions.where(
        date:                date,
        amount:              amount,
        transaction_type:    type,
        linked_account_type: linked_account ? linked_account.class.name : nil,
        linked_account_id:   linked_account&.id
      )
      scope = scope.where(bank_ref: bank_ref) if bank_ref
      scope = scope.where("transactions.created_at < ?", batch.created_at) if batch
      scope.first
    end

    def register_duplicate(existing)
      reference =
        if existing.bank_ref.present?
          "bank_ref #{existing.bank_ref}"
        else
          "#{existing.date}, ₹#{existing.amount} #{existing.transaction_type}"
        end

      @batch.import_records.create!(
        importable: existing,
        row_index:  @idx,
        status:     :skipped,
        notes:      "Duplicate of Transaction ##{existing.id} (#{reference})"
      )
      DUPLICATE
    end

    # Two paths:
    # 1. Canonical CSV — each row carries a nickname, look it up per-row.
    # 2. Bank-format Excel (ICICI) — rows don't carry account info, so the
    #    user picked the target account when creating the import batch and
    #    it's stored on the batch itself.
    def resolve_linked_account
      nickname = @row[:linked_account_nickname].presence
      if nickname
        return @user.accounts
                   .where("LOWER(nickname) = ?", nickname.downcase)
                   .first
      end

      return nil unless @batch.linked_account_type && @batch.linked_account_id
      @batch.linked_account_type.safe_constantize&.find_by(id: @batch.linked_account_id, user_id: @user.id)
    end

    def parse_tags(raw)
      return nil if raw.blank?
      raw.to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def parse_date!(value)
      self.class.parse_date!(value)
    end

    def self.parse_date!(value)
      raw = value.to_s.strip
      raise Imports::Error.new("date is required", code: :date_invalid) if raw.blank?

      DATE_FORMATS.each do |fmt|
        parsed = Date.strptime(raw, fmt)
        return parsed if parsed.strftime(fmt) == raw
      rescue ArgumentError
        next
      end

      raise Imports::Error.new(
        "Invalid date: \"#{raw}\" — expected YYYY-MM-DD, DD/MM/YYYY, or DD-MM-YYYY",
        code: :date_invalid, context: { raw: raw }
      )
    end
  end
end
