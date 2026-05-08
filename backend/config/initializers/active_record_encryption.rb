# Active Record encryption keys.
#
# These can come from credentials (production) or environment variables (dev/test).
# Generate fresh values with: bin/rails db:encryption:init
#
# In development & test we read from env vars for portability so the keys live in
# `.env` (gitignored) instead of having to edit Rails credentials.

if Rails.application.credentials.dig(:active_record_encryption, :primary_key).blank?
  # Hard-coded fallbacks for the test env so CI and fresh checkouts work without
  # secrets ceremony. NOT real keys — encrypted data in test DBs has no security
  # value. Dev / production must supply real keys via env or credentials.
  test_primary       = "test_encryption_primary_key_xxxxxxxxxxxxxxxx"
  test_deterministic = "test_encryption_deterministic_key_xxxxxxxxxxxxx"
  test_salt          = "test_encryption_key_derivation_salt_xxxxxxxxxxx"

  config = Rails.application.config.active_record.encryption
  # `presence` so an empty-string env var falls through to the test fallback.
  config.primary_key         = ENV["AR_ENCRYPTION_PRIMARY_KEY"].presence         || (Rails.env.test? ? test_primary       : nil)
  config.deterministic_key   = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"].presence   || (Rails.env.test? ? test_deterministic : nil)
  config.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"].presence || (Rails.env.test? ? test_salt          : nil)
end
