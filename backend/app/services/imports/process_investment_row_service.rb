module Imports
  class ProcessInvestmentRowService
    DATE_FORMATS = [ "%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y" ].freeze

    # Returned (instead of an Investment record) when the row matches an
    # existing investment by a strong dedupe key. The job uses this sentinel
    # to bump ImportBatch#duplicate_rows.
    DUPLICATE = :duplicate

    def initialize(batch, row, idx)
      @batch = batch
      @user  = batch.user
      @row   = row
      @idx   = idx
    end

    def call
      investment_type = normalize_type!
      trade_type      = normalize_trade_type!

      instrument      = resolve_instrument(investment_type)
      # Bulk path — skip the first-time backfill so a CSV with 100 new
      # instruments doesn't fan out 25k+ Sidekiq jobs. The user can run
      # `instruments:backfill_prices` once after the import to populate.
      user_instrument = Instruments::TrackService.new(@user, instrument).track(backfill: false)
      platform_account = resolve_platform_account

      amount_invested = @row[:amount_invested].to_f
      purchase_date   = parse_date!(@row[:purchase_date])

      # `price` is the unified per-share / per-unit price column. For backwards
      # compatibility we still accept legacy `buy_price` and `nav_at_purchase`
      # in CSV files exported before the schema unification.
      price = (@row[:price].presence || @row[:buy_price].presence || @row[:nav_at_purchase].presence)&.to_f

      if (existing = find_duplicate(user_instrument, platform_account, purchase_date, amount_invested, trade_type))
        return register_duplicate(existing)
      end

      investment = Investment.create!(
        user:                @user,
        source:              :imported,
        trade_type:          trade_type,
        investment_type:     investment_type,
        name:                instrument.name,
        amount_invested:     amount_invested,
        current_value:       @row[:current_value].presence&.to_f,
        purchase_date:       purchase_date,
        quantity:            @row[:quantity].presence&.to_f,
        units:               @row[:units].presence&.to_f,
        price:               price,
        order_id:            @row[:order_id].presence,
        trade_id:            @row[:trade_id].presence,
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
      investment
    end

    private

    # Dedupe ladder, strongest key first:
    #   1. trade_id  — broker-assigned, globally unique per fill
    #   2. order_id + purchase_date — covers files where trade_id is absent
    #      but order_id is reused only within the same date for that user
    #   3. structural exact match — instrument × platform × date × amount × side
    def find_duplicate(user_instrument, platform_account, purchase_date, amount_invested, trade_type)
      trade_id = @row[:trade_id].presence
      if trade_id
        existing = @user.investments.find_by(trade_id: trade_id)
        return existing if existing
      end

      order_id = @row[:order_id].presence
      if order_id
        existing = @user.investments.find_by(order_id: order_id, purchase_date: purchase_date)
        return existing if existing
      end

      return nil unless user_instrument && platform_account
      @user.investments.find_by(
        user_instrument_id:  user_instrument.id,
        platform_account_id: platform_account.id,
        purchase_date:       purchase_date,
        amount_invested:     amount_invested,
        trade_type:          trade_type
      )
    end

    def register_duplicate(existing)
      reference =
        if existing.trade_id.present?
          "trade_id #{existing.trade_id}"
        elsif existing.order_id.present?
          "order_id #{existing.order_id}"
        else
          "purchase_date #{existing.purchase_date}, amount #{existing.amount_invested}"
        end

      @batch.import_records.create!(
        importable: existing,
        row_index:  @idx,
        status:     :skipped,
        notes:      "Duplicate of Investment ##{existing.id} (#{reference})"
      )
      DUPLICATE
    end

    def normalize_type!
      raw = @row[:investment_type].to_s.strip.downcase
      unless Investment.investment_types.key?(raw)
        raise "investment_type \"#{raw}\" is not valid (stock/mutual_fund)"
      end
      raw
    end

    def normalize_trade_type!
      raw = @row[:trade_type].to_s.strip.downcase
      return "buy" if raw.empty? # default for files without the column
      mapped = case raw
      when "buy", "b", "purchase" then "buy"
      when "sell", "s", "sale", "exit" then "sell"
      else raw
      end
      unless Investment.trade_types.key?(mapped)
        raise "trade_type \"#{@row[:trade_type]}\" is not valid (buy/sell)"
      end
      mapped
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
