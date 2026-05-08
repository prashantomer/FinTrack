require "net/http"
require "uri"

module Instruments
  # Shared HTTP GET helper with redirect-following + a sane default UA. Pulled
  # out of PriceFetchService so PriceBackfillService can reuse it without
  # duplicating the retry/redirect dance.
  module HttpFetcher
    DEFAULT_UA = "Mozilla/5.0 (compatible; FinTrack/1.0)".freeze
    MAX_REDIRECTS = 10

    module_function

    def get(url, extra_headers: {})
      uri = URI(url)
      headers = { "User-Agent" => DEFAULT_UA }.merge(extra_headers)

      MAX_REDIRECTS.times do
        req = Net::HTTP::Get.new(uri, headers)
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }

        case res
        when Net::HTTPSuccess     then return res.body
        when Net::HTTPNotFound    then raise NotFound, "HTTP 404 from #{uri}"
        when Net::HTTPRedirection then uri = URI(res["location"])
        else                           raise "HTTP #{res.code} from #{uri}"
        end
      end
      raise "Too many redirects for #{url}"
    end

    # Distinct error type so callers can rescue 404 specifically — used by the
    # NSE backfill to recognise non-trading days vs other failures.
    class NotFound < StandardError; end
  end
end
