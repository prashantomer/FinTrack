require "net/http"
require "uri"
require "csv"
require "bigdecimal"

NSE_URL                  = "https://archives.nseindia.com/content/equities/EQUITY_L.csv"
NSE_BHAVCOPY_URL_FORMAT  = "https://archives.nseindia.com/products/content/sec_bhavdata_full_%s.csv"
AMFI_URL                 = "https://www.amfiindia.com/spages/NAVAll.txt"
LOG_PATH                 = Rails.root.join("../logs/instrument_fetch.log").cleanpath

def fetch_url(url, extra_headers: {})
  uri = URI(url)
  headers = { "User-Agent" => "Mozilla/5.0 (compatible; FinTrack/1.0)" }.merge(extra_headers)

  10.times do
    req = Net::HTTP::Get.new(uri, headers)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }

    case res
    when Net::HTTPSuccess
      return res.body
    when Net::HTTPRedirection
      uri = URI(res["location"])
    else
      raise "HTTP #{res.code} from #{uri}"
    end
  end

  raise "Too many redirects for #{url}"
end

# Try the most recent business days; NSE bhavcopy is published once per trading day.
def fetch_latest_nse_bhavcopy(log)
  7.times do |i|
    date = Date.current - i
    next if date.saturday? || date.sunday?
    url = format(NSE_BHAVCOPY_URL_FORMAT, date.strftime("%d%m%Y"))
    log.info "Trying NSE bhavcopy for #{date} → #{url}"
    begin
      body = fetch_url(url, extra_headers: { "Referer" => "https://www.nseindia.com/" })
      log.info "NSE bhavcopy found for #{date} (#{body.bytesize} bytes)"
      return [ body, date ]
    rescue => e
      log.info "Not available: #{e.message}"
    end
  end
  raise "No NSE bhavcopy available in the last 7 days"
end

def instrument_logger
  @instrument_logger ||= begin
    LOG_PATH.dirname.mkpath
    log = Logger.new(LOG_PATH, progname: "instruments")
    log.formatter = ->(sev, time, _, msg) { "#{time.strftime('%Y-%m-%d %H:%M:%S')}  #{sev.ljust(5)}  #{msg}\n" }
    log
  end
end

namespace :instruments do
  desc "Fetch NSE stocks and AMFI mutual funds and upsert into instruments table"
  task fetch: :environment do
    log = instrument_logger

    log.info "===== instruments:fetch started ====="

    # ── NSE stocks ──────────────────────────────────────────────────────────

    log.info "Fetching NSE equities from #{NSE_URL}"
    nse_csv = fetch_url(NSE_URL)
    log.info "Received #{nse_csv.bytesize} bytes"

    existing_stocks = Instrument.where(investment_type: "stock").where.not(isin: nil)
                                .index_by(&:isin)
    log.info "Existing stocks in DB: #{existing_stocks.size}"

    nse_added = nse_updated = nse_skipped = 0

    CSV.parse(nse_csv, headers: true, header_converters: :symbol) do |row|
      series = row[:series]&.strip
      unless series == "EQ"
        nse_skipped += 1
        next
      end

      isin = row[:isin_number]&.strip
      unless isin.present?
        nse_skipped += 1
        next
      end

      name   = row[:name_of_company]&.strip
      ticker = row[:symbol]&.strip&.first(20)

      if (inst = existing_stocks[isin])
        changes = []
        changes << "name"   if inst.name != name   && inst.update_column(:name, name)
        changes << "ticker" if inst.ticker_symbol != ticker && inst.update_column(:ticker_symbol, ticker)
        if changes.any?
          log.info "UPDATE stock #{ticker.ljust(12)} #{isin} #{name} [#{changes.join(', ')}]"
          nse_updated += 1
        else
          nse_skipped += 1
        end
      else
        Instrument.create!(
          name: name, investment_type: "stock",
          ticker_symbol: ticker, isin: isin, exchange: "NSE"
        )
        log.info "ADD    stock #{ticker.ljust(12)} #{isin} #{name}"
        nse_added += 1
      end
    end

    log.info "NSE done — added=#{nse_added}  updated=#{nse_updated}  skipped=#{nse_skipped}"
    puts "NSE stocks: +#{nse_added} added, #{nse_updated} updated, #{nse_skipped} skipped"

    # ── AMFI mutual funds ────────────────────────────────────────────────────

    log.info "Fetching AMFI NAVAll from #{AMFI_URL}"
    amfi_text = fetch_url(AMFI_URL)
    log.info "Received #{amfi_text.bytesize} bytes"

    existing_mfs = Instrument.where(investment_type: "mutual_fund").where.not(isin: nil)
                             .index_by(&:isin)
    log.info "Existing mutual funds in DB: #{existing_mfs.size}"

    mf_added = mf_updated = mf_skipped = 0
    current_amc = nil
    to_insert = []

    amfi_text.each_line do |raw|
      line = raw.strip
      next if line.empty?
      next if line.start_with?("Scheme Code;")
      next if line.start_with?("Open Ended", "Close Ended", "Interval")

      if line.exclude?(";")
        current_amc = line.delete_suffix(";").strip
        next
      end

      parts = line.split(";")
      next if parts.size < 4

      scheme_name = parts[3].strip
      name_lower  = scheme_name.downcase
      unless name_lower.include?("direct") && name_lower.include?("growth")
        mf_skipped += 1
        next
      end

      isin = parts[1].strip
      isin = parts[2].strip if isin.blank? || isin == "-"
      if isin.blank? || isin == "-"
        mf_skipped += 1
        next
      end

      fund_house = current_amc&.first(100)
      name       = scheme_name.first(255)

      if (inst = existing_mfs[isin])
        changes = []
        changes << "name"       if inst.name != name       && inst.update_column(:name, name)
        changes << "fund_house" if inst.fund_house != fund_house && inst.update_column(:fund_house, fund_house)
        if changes.any?
          log.info "UPDATE mf #{isin} #{name.first(60)} [#{changes.join(', ')}]"
          mf_updated += 1
        else
          mf_skipped += 1
        end
      else
        to_insert << { name: name, investment_type: "mutual_fund", isin: isin, fund_house: fund_house }
        log.info "ADD    mf #{isin} #{(fund_house || '').ljust(30).first(30)} #{name.first(60)}"
        mf_added += 1
      end
    end

    to_insert.each_slice(500) { |batch| Instrument.insert_all!(batch) }

    log.info "AMFI done — added=#{mf_added}  updated=#{mf_updated}  skipped=#{mf_skipped}"
    puts "AMFI MFs:   +#{mf_added} added, #{mf_updated} updated, #{mf_skipped} skipped"

    log.info "===== instruments:fetch complete ====="
  end

  desc "Fetch current stock close prices (NSE bhavcopy) and mutual fund NAVs (AMFI) into instruments.last_price"
  task fetch_prices: :environment do
    log = instrument_logger
    log.info "===== instruments:fetch_prices started ====="

    # ── NSE stock close prices via bhavcopy ─────────────────────────────────
    nse_csv, nse_date = fetch_latest_nse_bhavcopy(log)

    by_ticker = Instrument.where(investment_type: "stock").where.not(ticker_symbol: nil)
                          .index_by { |i| i.ticker_symbol.upcase }
    log.info "Stocks indexed by ticker: #{by_ticker.size}"

    nse_at = nse_date.in_time_zone.beginning_of_day
    nse_updated = nse_unchanged = nse_unmatched = 0

    CSV.parse(nse_csv, headers: true, header_converters: ->(h) { h.to_s.strip.downcase.to_sym }) do |row|
      next unless row[:series]&.strip == "EQ"

      ticker = row[:symbol]&.strip
      close  = row[:close_price]&.strip
      next if ticker.blank? || close.blank?

      inst = by_ticker[ticker.upcase]
      unless inst
        nse_unmatched += 1
        next
      end

      price = BigDecimal(close)
      if inst.last_price == price && inst.last_price_at == nse_at
        nse_unchanged += 1
      else
        inst.update_columns(last_price: price, last_price_at: nse_at)
        nse_updated += 1
      end
    end

    log.info "NSE done — updated=#{nse_updated} unchanged=#{nse_unchanged} unmatched_in_db=#{nse_unmatched}"
    puts "NSE stocks: #{nse_updated} updated (#{nse_unchanged} unchanged) for #{nse_date}"

    # ── AMFI mutual fund NAVs ───────────────────────────────────────────────
    log.info "Fetching AMFI NAVAll from #{AMFI_URL}"
    amfi_text = fetch_url(AMFI_URL)
    log.info "Received #{amfi_text.bytesize} bytes"

    by_isin = Instrument.where(investment_type: "mutual_fund").where.not(isin: nil).index_by(&:isin)
    log.info "Mutual funds indexed by ISIN: #{by_isin.size}"

    mf_updated = mf_unchanged = mf_unmatched = mf_invalid = 0

    amfi_text.each_line do |raw|
      line = raw.strip
      next if line.empty?
      next if line.start_with?("Scheme Code;")
      next if line.start_with?("Open Ended", "Close Ended", "Interval")
      next if line.exclude?(";")

      parts = line.split(";")
      next if parts.size < 6

      isin1 = parts[1].strip
      isin2 = parts[2].strip
      nav   = parts[4].strip
      date  = parts[5].strip

      inst = by_isin[isin1] || by_isin[isin2]
      unless inst
        mf_unmatched += 1
        next
      end

      if nav.blank? || nav.casecmp?("N.A.") || nav == "-"
        mf_invalid += 1
        next
      end

      price = (BigDecimal(nav) rescue nil)
      nav_at = (Date.strptime(date, "%d-%b-%Y").in_time_zone.beginning_of_day rescue nil)
      unless price && nav_at
        mf_invalid += 1
        next
      end

      if inst.last_price == price && inst.last_price_at == nav_at
        mf_unchanged += 1
      else
        inst.update_columns(last_price: price, last_price_at: nav_at)
        mf_updated += 1
      end
    end

    log.info "AMFI done — updated=#{mf_updated} unchanged=#{mf_unchanged} unmatched_in_db=#{mf_unmatched} invalid=#{mf_invalid}"
    puts "AMFI MFs:   #{mf_updated} updated (#{mf_unchanged} unchanged, #{mf_invalid} invalid)"

    log.info "===== instruments:fetch_prices complete ====="
  end
end
