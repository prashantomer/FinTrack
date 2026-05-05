module Imports
  class ProcessTransactionRowService
    DATE_FORMATS = [ "%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y" ].freeze

    def initialize(batch, row, idx)
      @batch = batch
      @user  = batch.user
      @row   = row
      @idx   = idx
    end

    def call
      date   = parse_date!(@row[:date])
      amount = @row[:amount].to_f
      raise "amount must be greater than 0" unless amount > 0

      type = @row[:type].to_s.strip.downcase
      raise "type must be 'credit' or 'debit'" unless %w[credit debit].include?(type)

      linked_account = resolve_linked_account
      tags           = parse_tags(@row[:tags])

      txn = Transaction.create!(
        user:                 @user,
        amount:               amount,
        transaction_type:     type,
        date:                 date,
        description:          @row[:description].presence,
        tags:                 tags,
        bank_ref:             @row[:bank_ref].presence,
        linked_account_type:  linked_account ? linked_account.class.name : nil,
        linked_account_id:    linked_account&.id
      )

      @batch.import_records.create!(
        importable: txn,
        row_index:  @idx,
        status:     :ok,
        notes:      linked_account ? "Linked to account: #{linked_account.nickname}" : nil
      )
    end

    private

    def resolve_linked_account
      nickname = @row[:linked_account_nickname].presence
      return nil unless nickname

      @user.accounts
           .where("LOWER(nickname) = ?", nickname.downcase)
           .first
    end

    def parse_tags(raw)
      return nil if raw.blank?
      raw.to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def parse_date!(value)
      raw = value.to_s.strip
      raise "date is required" if raw.blank?

      DATE_FORMATS.each do |fmt|
        parsed = Date.strptime(raw, fmt)
        return parsed if parsed.strftime(fmt) == raw
      rescue ArgumentError
        next
      end

      raise "Invalid date: \"#{raw}\" — expected YYYY-MM-DD, DD/MM/YYYY, or DD-MM-YYYY"
    end
  end
end
