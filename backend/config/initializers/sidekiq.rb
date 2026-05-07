# Sidekiq Redis configuration.
#
# Redis is logically partitioned by db number for clean isolation between
# subsystems. Conventions:
#   db 0 — Sidekiq queues, scheduled set, retry/dead sets
#   db 1 — Rails cache (when configured to use redis-store)
#   db 2 — reserved for future caches / rate-limiters
#
# Override per-process via env vars when needed (e.g. parallel test runs):
#   REDIS_URL              base host (no db suffix), defaults to localhost:6379
#   SIDEKIQ_REDIS_DB       db number for Sidekiq, defaults to 0

REDIS_BASE_URL = (Rails.application.credentials.redis_url ||
                  ENV.fetch("REDIS_URL", "redis://localhost:6379")).sub(%r{/\d+\z}, "")
SIDEKIQ_REDIS_DB = ENV.fetch("SIDEKIQ_REDIS_DB", "0")

sidekiq_redis_url = "#{REDIS_BASE_URL}/#{SIDEKIQ_REDIS_DB}"

Sidekiq.configure_server { |c| c.redis = { url: sidekiq_redis_url } }
Sidekiq.configure_client { |c| c.redis = { url: sidekiq_redis_url } }
