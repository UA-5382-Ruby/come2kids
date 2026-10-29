allowed_origins = lambda do
  ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",").filter_map do |origin|
    origin.strip.presence
  end
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins { |origin, _env| allowed_origins.call.include?(origin) }

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
