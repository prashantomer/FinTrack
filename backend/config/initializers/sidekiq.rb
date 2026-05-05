redis_url = Rails.application.credentials.redis_url || ENV.fetch("REDIS_URL", "redis://localhost:6379")

Sidekiq.configure_server { |c| c.redis = { url: redis_url } }
Sidekiq.configure_client { |c| c.redis = { url: redis_url } }
