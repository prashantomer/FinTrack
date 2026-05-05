Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      Rails.env.development? ? "http://localhost:5173" : ENV.fetch("ALLOWED_ORIGIN", "")
    )

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end
