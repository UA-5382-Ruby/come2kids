# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

# The API authenticates with the Authorization header only (no cookies), so CORS credentials
# are not needed. Origins are still an explicit list from FRONTEND_ORIGIN.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    default_origin = Rails.env.local? ? "http://localhost:5173" : ""
    origins(*ENV.fetch("FRONTEND_ORIGIN", default_origin).split(",").map(&:strip).reject(&:blank?))

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
