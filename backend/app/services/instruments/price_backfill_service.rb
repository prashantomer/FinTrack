require "csv"
require "bigdecimal"

module Instruments
  # Backfills daily price history for tracked instruments. Two entry points,
  # one per data source, each scoped by the calling job to a small id/ISIN set
  # so we don't process the entire 6k+ catalogue every time.
  #
  # Idempotent — same-day re-runs upsert into instrument_price_history.
  class PriceBackfillService
    NSE_BHAVCOPY_URL_FORMAT = "https://archives.nseindia.com/products/content/sec_bhavdata_full_%s.csv".freeze

    # The portal endpoint accepts arbitrary date ranges and returns a NAVAll-
    # style stream with a date column per row. Empirically the cap is ~3 months,
    # so callers should chunk to ~30 days for headroom.
    AMFI_HISTORY_URL = "https://portal.amfiindia.com/DownloadNAVHistoryReport_Po.aspx?frmdt=%s&todt=%s".freeze

    NseResult  = Struct.new(:date, :inserted, :unmatched, :skipped_non_trading, keyword_init: true)
    AmfiResult = Struct.new(:from_date, :to_date, :inserted, :unmatched, :invalid, keyword_init: true)

    # ── NSE bhavcopy for one trading day ────────────────────────────────────
    #
    # `stock_instrument_ids` should already be the tracked subset; the rake
    # task computes it once and passes the same list to every per-day job.
    def self.nse_for_date(date, stock_instrument_ids, logger: Rails.logger)
      return NseResult.new(date: date, inserted: 0, unmatched: 0, skipped_non_trading: true) if date.saturday? || date.sunday?
      return NseResult.new(date: date, inserted: 0, unmatched: 0, skipped_non_trading: false) if stock_instrument_ids.empty?

      url = format(NSE_BHAVCOPY_URL_FORMAT, date.strftime("%d%m%Y"))
      begin
        body = HttpFetcher.get(url, extra_headers: { "Referer" => "https://www.nseindia.com/" })
      rescue HttpFetcher::NotFound
        # Holidays + the long tail of dates NSE never published for. Return a
        # silent no-op result instead of raising — the rake task fans out one
        # job per weekday and we expect ~10-15 holidays per year.
        logger.info "[backfill nse #{date}] no bhavcopy (holiday or unavailable)"
        return NseResult.new(date: date, inserted: 0, unmatched: 0, skipped_non_trading: true)
      end

      tracked = stock_instrument_ids.to_set
      by_ticker = Instrument.where(id: stock_instrument_ids).where.not(ticker_symbol: nil)
                            .index_by { |i| i.ticker_symbol.upcase }

      rows = []
      unmatched = 0

      CSV.parse(body, headers: true, header_converters: ->(h) { h.to_s.strip.downcase.to_sym }) do |row|
        next unless row[:series]&.strip == "EQ"
        ticker = row[:symbol]&.strip
        close  = row[:close_price]&.strip
        next if ticker.blank? || close.blank?

        inst = by_ticker[ticker.upcase]
        unless inst && tracked.include?(inst.id)
          unmatched += 1
          next
        end

        price = (BigDecimal(close) rescue nil)
        next unless price

        rows << {
          instrument_id: inst.id,
          price_date:    date,
          price:         price,
          source:        "nse_bhavcopy"
        }
      end

      inserted = PriceHistoryUpsert.call(rows)
      logger.info "[backfill nse #{date}] inserted=#{inserted} unmatched=#{unmatched}"
      NseResult.new(date: date, inserted: inserted, unmatched: unmatched, skipped_non_trading: false)
    end

    # ── AMFI historical NAV for a date range ────────────────────────────────
    #
    # `mf_isins` should be the tracked subset. The portal returns rows for
    # every scheme in the system across the requested range; we filter against
    # this set in-process to keep the tracked-only invariant.
    def self.amfi_for_range(from_date, to_date, mf_isins, logger: Rails.logger)
      return AmfiResult.new(from_date: from_date, to_date: to_date, inserted: 0, unmatched: 0, invalid: 0) if mf_isins.empty?

      url = format(
        AMFI_HISTORY_URL,
        from_date.strftime("%d-%b-%Y"),
        to_date.strftime("%d-%b-%Y")
      )
      body = HttpFetcher.get(url)

      tracked_isins = mf_isins.to_set
      isin_to_id    = Instrument.where(investment_type: "mutual_fund", isin: mf_isins).pluck(:isin, :id).to_h

      rows = []
      unmatched = invalid = 0

      # Portal column order (different from NAVAll.txt!):
      #   0 Scheme Code
      #   1 Scheme Name
      #   2 ISIN Div Payout/ISIN Growth      ← primary match key
      #   3 ISIN Div Reinvestment            ← fallback match key
      #   4 Net Asset Value
      #   5 Repurchase Price                 ← ignored
      #   6 Sale Price                       ← ignored
      #   7 Date                             (DD-MMM-YYYY)
      body.each_line do |raw|
        line = raw.strip
        next if line.empty?
        next if line.start_with?("Scheme Code;")
        next if line.start_with?("Open Ended", "Close Ended", "Interval")
        next if line.exclude?(";")

        parts = line.split(";")
        next if parts.size < 8

        isin1 = parts[2].strip
        isin2 = parts[3].strip
        nav   = parts[4].strip
        date  = parts[7].strip

        isin = isin1 if tracked_isins.include?(isin1)
        isin ||= isin2 if tracked_isins.include?(isin2)
        unless isin
          unmatched += 1
          next
        end

        if nav.blank? || nav.casecmp?("N.A.") || nav == "-"
          invalid += 1
          next
        end

        price  = (BigDecimal(nav) rescue nil)
        nav_d  = (Date.strptime(date, "%d-%b-%Y") rescue nil)
        unless price && nav_d
          invalid += 1
          next
        end

        instrument_id = isin_to_id[isin]
        next unless instrument_id

        rows << {
          instrument_id: instrument_id,
          price_date:    nav_d,
          price:         price,
          source:        "amfi_navhistory"
        }
      end

      inserted = PriceHistoryUpsert.call(rows)
      logger.info "[backfill amfi #{from_date}..#{to_date}] inserted=#{inserted} unmatched=#{unmatched} invalid=#{invalid}"
      AmfiResult.new(
        from_date: from_date, to_date: to_date,
        inserted: inserted, unmatched: unmatched, invalid: invalid
      )
    end
  end
end
