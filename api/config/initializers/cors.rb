origins = ENV["FRONTEND_ORIGINS"].presence ||
  (Rails.env.production? ? nil : "http://localhost:3000")

if origins.blank? && Rails.env.production?
  raise "FRONTEND_ORIGINS must be configured in production"
end

allowed_origins = origins.to_s.split(",").filter_map(&:strip).reject(&:empty?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: %w[Accept Authorization Content-Type Idempotency-Key],
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization],
      max_age: 600
  end
end
