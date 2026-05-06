# Active Record encryption keys.
#
# These can come from credentials (production) or environment variables (dev/test).
# Generate fresh values with: bin/rails db:encryption:init
#
# In development & test we read from env vars for portability so the keys live in
# `.env` (gitignored) instead of having to edit Rails credentials.

if Rails.application.credentials.dig(:active_record_encryption, :primary_key).blank?
  Rails.application.config.active_record.encryption.primary_key          = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
  Rails.application.config.active_record.encryption.deterministic_key    = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
  Rails.application.config.active_record.encryption.key_derivation_salt  = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
end
