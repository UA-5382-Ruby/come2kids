# frozen_string_literal: true

# Outside production, without FRONTEND_ORIGINS: the API itself (Swagger UI) and the Vite frontend,
# reachable as localhost, 127.0.0.1 or 0.0.0.0.
development_origins = [ ENV.fetch('PORT', '3000'), '5173' ].uniq.flat_map do |port|
  %w[localhost 127.0.0.1 0.0.0.0].map { |host| "http://#{host}:#{port}" }
end

origins = ENV['FRONTEND_ORIGINS'].presence ||
  (Rails.env.production? ? nil : development_origins.join(','))

if origins.blank? && Rails.env.production?
  raise 'FRONTEND_ORIGINS must be configured in production'
end

allowed_origins = origins.to_s.split(',').filter_map(&:strip).reject(&:empty?)

if allowed_origins.empty?
  raise 'FRONTEND_ORIGINS must contain at least one valid origin'
end

if allowed_origins.include?('*')
  raise 'FRONTEND_ORIGINS must list explicit origins; wildcard origins are not allowed'
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource '*',
      headers: %w[Accept Authorization Content-Type Idempotency-Key],
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization],
      max_age: 600
  end
end
