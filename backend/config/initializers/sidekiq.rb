redis_url = Rails.application.credentials.redis_url || ENV.fetch("REDIS_URL", "redis://localhost:6379")

Sidekiq.configure_server do |c|
  c.redis = { url: redis_url }

  # Load sidekiq-cron schedule. Only the server process registers schedules
  # so multiple web pods don't fight over the cron entries.
  c.on(:startup) do
    schedule_file = Rails.root.join("config/sidekiq_cron.yml")
    if schedule_file.exist? && defined?(Sidekiq::Cron::Job)
      schedule = YAML.load_file(schedule_file) || {}
      Sidekiq::Cron::Job.load_from_hash(schedule)
    end
  end
end

Sidekiq.configure_client { |c| c.redis = { url: redis_url } }
