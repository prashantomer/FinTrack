require "rack/attack"

class Rack::Attack
  # Throttle assistant message creation per user. The limit is per-user from
  # their UserAssistantSetting (default 100/day).
  throttle("assistant_messages_per_user", limit: ->(req) { user_daily_limit(req) || 100 }, period: 24.hours) do |req|
    if req.path == "/api/v1/assistant/messages" && req.post?
      user_id_from_token(req)
    end
  end

  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"]
    [
      429,
      { "Content-Type" => "application/json" },
      [ {
        success: false,
        code: 429,
        error: "Daily assistant message limit reached.",
        meta_data: {
          limit: match_data[:limit],
          period_seconds: match_data[:period],
          retry_after_seconds: match_data[:period] - (Time.now.to_i - match_data[:epoch_time])
        }
      }.to_json ]
    ]
  end

  class << self
    def user_id_from_token(req)
      header = req.get_header("HTTP_AUTHORIZATION").to_s
      return nil unless header.start_with?("Bearer ")
      payload = JsonWebToken.decode(header.sub("Bearer ", ""))
      payload && payload["user_id"]
    rescue StandardError
      nil
    end

    def user_daily_limit(req)
      uid = user_id_from_token(req)
      return nil unless uid
      Rails.cache.fetch("rack_attack/assistant_limit/#{uid}", expires_in: 5.minutes) do
        UserAssistantSetting.where(user_id: uid).pick(:daily_limit) || 100
      end
    end
  end
end
