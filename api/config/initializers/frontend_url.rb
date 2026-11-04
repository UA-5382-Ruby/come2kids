Rails.configuration.x.frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173").chomp("/")
