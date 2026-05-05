require "net/http"
require "uri"
require "csv"

NSE_URL  = "https://archives.nseindia.com/content/equities/EQUITY_L.csv"
AMFI_URL = "https://www.amfiindia.com/spages/NAVAll.txt"
LOG_PATH = Rails.root.join("../logs/instrument_fetch.log").cleanpath

def fetch_url(url)
  uri = URI(url)
  headers = { "User-Agent" => "Mozilla/5.0 (compatible; FinTrack/1.0)" }

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
end
