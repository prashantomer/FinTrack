module JsonWebToken
  SECRET = Rails.application.credentials.secret_key_base
  EXPIRY = 7.days

  def self.encode(payload)
    JWT.encode(payload.merge(exp: EXPIRY.from_now.to_i), SECRET, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, SECRET, true, algorithm: "HS256").first
  rescue JWT::DecodeError
    nil
  end
end
