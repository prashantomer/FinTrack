module Imports
  class ProcessInvestmentRowService
    DATE_FORMATS = [ "%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y" ].freeze

    def initialize(batch, row, idx)
      @batch = batch
      @user  = batch.user
      @row   = row
      @idx   = idx
    end

    def call
      investment_type = normalize_type!

      instrument      = resolve_instrument(investment_type)
      user_instrument = Instruments::TrackService.new(@user, instrument).track
      platform_account = resolve_platform_account

      follio = resolve_follio(user_instrument, platform_account)

      amount_invested = @row[:amount_invested].to_f
      purchase_date   = parse_date!(@row[:purchase_date])

      investment = Investment.create!(
        user:                @user,
        investment_type:     investment_type,
        name:                instrument.name,
        amount_invested:     amount_invested,
        current_value:       @row[:current_value].presence&.to_f,
        purchase_date:       purchase_date,
        quantity:            @row[:quantity].presence&.to_f,
        buy_price:           @row[:buy_price].presence&.to_f,
        units:               @row[:units].presence&.to_f,
        nav_at_purchase:     @row[:nav_at_purchase].presence&.to_f,
        folio_number:        @row[:folio_number].presence,
        notes:               @row[:notes].presence,
        user_instrument:     user_instrument,
        platform_account:    platform_account
      )

      matched_txn = match_transaction(amount_invested, purchase_date, instrument)

      @batch.import_records.create!(
        importable: investment,
        row_index:  @idx,
        status:     :ok,
        notes:      matched_txn ? "Linked to txn ##{matched_txn.id}" : nil
      )
    end

    private

    def normalize_type!
      raw = @row[:investment_type].to_s.strip.downcase
      unless Investment.investment_types.key?(raw)
        raise "investment_type \"#{raw}\" is not valid (stock/mutual_fund)"
      end
      raw
    end

    # Instrument resolution: ISIN → ticker → name fuzzy → create
    def resolve_instrument(investment_type)
      isin   = @row[:isin].presence
      ticker = @row[:ticker_symbol].presence
      name   = @row[:name].to_s.strip

      raise "name is required" if name.blank?

      instrument =
        (isin   && Instrument.find_by(isin: isin))                                          ||
        (ticker && Instrument.find_by("LOWER(ticker_symbol) = ?", ticker.downcase))         ||
        Instrument.where("LOWER(name) LIKE ?", "%#{name.downcase}%").first

      instrument || Instrument.create!(
        name:            name,
        investment_type: investment_type,
        isin:            isin,
        ticker_symbol:   @row[:ticker_symbol].presence,
        exchange:        @row[:exchange].presence,
        fund_house:      @row[:fund_house].presence
      )
    end

    # PlatformAccount resolution: nickname → platform name → create with fallback
    def resolve_platform_account
      platform_name = @row[:platform_name].presence
      return nil unless platform_name

      # 1. Match existing platform account by nickname or platform name
      match = @user.platform_accounts
                   .joins(:platform)
                   .where("LOWER(platform_accounts.nickname) = ? OR LOWER(platforms.name) = ?",
                          platform_name.downcase, platform_name.downcase)
                   .first
      return match if match

      # 2. Find platform by name
      platform = Platform.where("LOWER(name) = ?", platform_name.downcase).first

      # 3. Fallback to direct platform
      platform ||= Platform.find_by(platform_type: "direct")

      return nil unless platform

      @user.platform_accounts.create!(
        platform:  platform,
        nickname:  platform_name
      )
    end

    # Follio: find_or_create when folio_number + both associations present
    def resolve_follio(user_instrument, platform_account)
      folio_number = @row[:folio_number].presence
      return nil unless folio_number && user_instrument && platform_account

      Follio.find_or_create_by(
        user:             @user,
        user_instrument:  user_instrument,
        platform_account: platform_account
      ) { |f| f.folio_number = folio_number }
    end

    # Best-effort transaction matching — never raises
    def match_transaction(amount_invested, purchase_date, instrument)
      txn = @user.transactions.active
                 .where(transaction_type: "debit")
                 .where("ABS(amount - ?) < 1.0", amount_invested)
                 .where(date: (purchase_date - 3.days)..(purchase_date + 3.days))
                 .first
      txn&.update_column(:instrument_id, instrument.id)
      txn
    rescue
      nil
    end

    def parse_date!(value)
      raw = value.to_s.strip
      raise "purchase_date is required" if raw.blank?

      DATE_FORMATS.each do |fmt|
        parsed = Date.strptime(raw, fmt)
        return parsed if parsed.strftime(fmt) == raw
      rescue ArgumentError
        next
      end

      raise "Invalid purchase_date: \"#{raw}\" — expected YYYY-MM-DD, DD/MM/YYYY, or DD-MM-YYYY"
    end
  end
end
