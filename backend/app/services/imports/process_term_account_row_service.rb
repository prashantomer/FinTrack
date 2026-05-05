module Imports
  class ProcessTermAccountRowService
    DATE_FORMATS = ["%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y"].freeze

    def initialize(batch, row, idx)
      @batch = batch
      @user  = batch.user
      @row   = row
      @idx   = idx
    end

    def call
      account_type = @row[:account_type].to_s.strip.downcase
      raise "account_type must be 'fd' or 'ppf'" unless %w[fd ppf].include?(account_type)

      parent_account = resolve_parent_account!
      open_date      = parse_date!(@row[:open_date], "open_date")
      amount         = @row[:amount].to_f
      raise "amount must be greater than 0" unless amount > 0

      interest_rate  = @row[:interest_rate].to_f
      raise "interest_rate is required" unless interest_rate > 0

      attrs = {
        user:              @user,
        parent_account:    parent_account,
        account_type:      account_type,
        account_number:    @row[:account_number].presence,
        amount:            amount,
        open_date:         open_date,
        interest_rate:     interest_rate,
        balance:           @row[:balance].presence&.to_f || amount,
        is_active:         true
      }

      if account_type == "fd"
        tenure_days = @row[:tenure_days].presence&.to_i
        raise "tenure_days is required for FD" unless tenure_days&.positive?
        attrs[:tenure_days]     = tenure_days
        attrs[:maturity_date]   = @row[:maturity_date].presence ? parse_date!(@row[:maturity_date], "maturity_date") : nil
        attrs[:maturity_amount] = @row[:maturity_amount].presence&.to_f
      else
        attrs[:tenure_days]     = nil
        attrs[:maturity_date]   = @row[:maturity_date].presence ? parse_date!(@row[:maturity_date], "maturity_date") : nil
        attrs[:maturity_amount] = @row[:maturity_amount].presence&.to_f || 0
      end

      ta = TermAccount.create!(attrs)

      @batch.import_records.create!(
        importable: ta,
        row_index:  @idx,
        status:     :ok,
        notes:      "#{account_type.upcase} linked to account: #{parent_account.nickname}"
      )
    end

    private

    def resolve_parent_account!
      nickname = @row[:parent_account_nickname].to_s.strip
      raise "parent_account_nickname is required" if nickname.blank?

      account = @user.accounts
                     .where("LOWER(nickname) = ?", nickname.downcase)
                     .first
      raise "Account '#{nickname}' not found" unless account
      account
    end

    def parse_date!(value, field = "date")
      raw = value.to_s.strip
      raise "#{field} is required" if raw.blank?

      DATE_FORMATS.each do |fmt|
        return Date.strptime(raw, fmt)
      rescue ArgumentError
        next
      end

      raise "Invalid #{field}: \"#{raw}\" — expected YYYY-MM-DD, DD/MM/YYYY, or DD-MM-YYYY"
    end
  end
end
