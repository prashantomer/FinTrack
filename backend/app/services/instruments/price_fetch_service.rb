require "net/http"
require "uri"
require "csv"
require "bigdecimal"

module Instruments
  # Fetches NSE stock close prices (bhavcopy) and AMFI mutual fund NAVs.
  # Writes the latest value to `instruments.last_price` AND appends a row to
  # `instrument_price_history` for time-series tracking.
  #
  # Idempotent: re-running on the same day upserts the same price_date row.
  class PriceFetchService
    NSE_BHAVCOPY_URL_FORMAT = "https://archives.nseindia.com/products/content/sec_bhavdata_full_%s.csv".freeze
    AMFI_URL                = "https://www.amfiindia.com/spages/NAVAll.txt".freeze

    Result = Struct.new(:nse_updated, :nse_history_rows, :nse_unmatched,
                        :mf_updated,  :mf_history_rows,  :mf_unmatched, :mf_invalid,
                        keyword_init: true)

    def self.call(logger: Rails.logger)
      new(logger: logger).call
    end

    def initialize(logger:)
      @log = logger
    end

    def call
      nse = fetch_nse_prices
      mf  = fetch_amfi_navs
      Result.new(
        nse_updated:      nse[:updated],
        nse_history_rows: nse[:history_rows],
        nse_unmatched:    nse[:unmatched],
        mf_updated:       mf[:updated],
        mf_history_rows:  mf[:history_rows],
        mf_unmatched:     mf[:unmatched],
        mf_invalid:       mf[:invalid]
      )
    end

    private

    def fetch_nse_prices
      csv, date = latest_nse_bhavcopy
      by_ticker = Instrument.where(investment_type: "stock").where.not(ticker_symbol: nil)
                            .index_by { |i| i.ticker_symbol.upcase }

      updated = unmatched = 0
      history_rows = []
      now = Time.current
      bhav_at = date.in_time_zone.beginning_of_day

      CSV.parse(csv, headers: true, header_converters: ->(h) { h.to_s.strip.downcase.to_sym }) do |row|
        next unless row[:series]&.strip == "EQ"
        ticker = row[:symbol]&.strip
        close  = row[:close_price]&.strip
        next if ticker.blank? || close.blank?

        inst = by_ticker[ticker.upcase]
        unless inst
          unmatched += 1
          next
        end

        price = (BigDecimal(close) rescue nil)
        next unless price

        if inst.last_price != price || inst.last_price_at != bhav_at
          inst.update_columns(last_price: price, last_price_at: bhav_at)
          updated += 1
        end

        history_rows << {
          instrument_id: inst.id,
          price_date:    date,
          price:         price,
          source:        "nse_bhavcopy"
        }
      end

      inserted = upsert_history(history_rows)
      @log.info "[prices] NSE: updated=#{updated} history_rows=#{inserted} unmatched=#{unmatched}"
      { updated: updated, history_rows: inserted, unmatched: unmatched }
    end

    def fetch_amfi_navs
      body = fetch_url(AMFI_URL)
      by_isin = Instrument.where(investment_type: "mutual_fund").where.not(isin: nil).index_by(&:isin)

      updated = unmatched = invalid = 0
      history_rows = []
      now = Time.current

      body.each_line do |raw|
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
          unmatched += 1
          next
        end

        if nav.blank? || nav.casecmp?("N.A.") || nav == "-"
          invalid += 1
          next
        end

        price  = (BigDecimal(nav) rescue nil)
        nav_d  = (Date.strptime(date, "%d-%b-%Y") rescue nil)
        nav_at = nav_d&.in_time_zone&.beginning_of_day

        unless price && nav_at
          invalid += 1
          next
        end

        if inst.last_price != price || inst.last_price_at != nav_at
          inst.update_columns(last_price: price, last_price_at: nav_at)
          updated += 1
        end

        history_rows << {
          instrument_id: inst.id,
          price_date:    nav_d,
          price:         price,
          source:        "amfi_navall"
        }
      end

      inserted = upsert_history(history_rows)
      @log.info "[prices] AMFI: updated=#{updated} history_rows=#{inserted} unmatched=#{unmatched} invalid=#{invalid}"
      { updated: updated, history_rows: inserted, unmatched: unmatched, invalid: invalid }
    end

    def upsert_history(rows)
      return 0 if rows.empty?
      rows.each_slice(1_000).sum do |chunk|
        # ON CONFLICT (instrument_id, price_date) DO UPDATE — same-day re-runs
        # overwrite the price; created_at survives (excluded from update_only)
        # and updated_at is auto-bumped by Rails timestamp handling.
        InstrumentPriceHistory.upsert_all(
          chunk,
          unique_by:   :uq_instr_price_history_per_day,
          update_only: %i[price source]
        )
        chunk.size
      end
    end

    def latest_nse_bhavcopy
      7.times do |i|
        date = Date.current - i
        next if date.saturday? || date.sunday?
        url = format(NSE_BHAVCOPY_URL_FORMAT, date.strftime("%d%m%Y"))
        @log.info "[prices] Trying NSE bhavcopy #{date}"
        begin
          body = fetch_url(url, extra_headers: { "Referer" => "https://www.nseindia.com/" })
          return [ body, date ]
        rescue => e
          @log.info "[prices] Not available for #{date}: #{e.message}"
        end
      end
      raise "No NSE bhavcopy available in the last 7 days"
    end

    def fetch_url(url, extra_headers: {})
      uri = URI(url)
      headers = { "User-Agent" => "Mozilla/5.0 (compatible; FinTrack/1.0)" }.merge(extra_headers)

      10.times do
        req = Net::HTTP::Get.new(uri, headers)
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }

        case res
        when Net::HTTPSuccess     then return res.body
        when Net::HTTPRedirection then uri = URI(res["location"])
        else                           raise "HTTP #{res.code} from #{uri}"
        end
      end
      raise "Too many redirects for #{url}"
    end
  end
end
