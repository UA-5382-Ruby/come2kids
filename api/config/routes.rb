# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI — protect with HTTP Basic when credentials are configured.
  if ENV["SIDEKIQ_USERNAME"].present? && ENV["SIDEKIQ_PASSWORD"].present?
    Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(username),
        ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_USERNAME"))
      ) & ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_PASSWORD"))
      )
    end
  end

  mount Sidekiq::Web => "/sidekiq"
end
