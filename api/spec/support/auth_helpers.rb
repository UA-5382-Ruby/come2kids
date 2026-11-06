# frozen_string_literal: true

module AuthHelpers
  # Headers of a request made by `user` with a valid access token.
  def auth_headers(user)
    { "Authorization" => "Bearer #{JwtService.encode(user)}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
end
