# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  get "/users/me", to: "users#show"
  put "/users/me", to: "users#update"

  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

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

  namespace :api do
    namespace :v1 do
      # Логін поза namespace :auth, бо контролер на рівень вище
      post "auth/login", to: "auth#login"

      namespace :auth do
        post "register", to: "registrations#create"
        post "confirm-email", to: "email_confirmations#confirm"
        post "resend-confirmation", to: "email_confirmations#resend"
      end

      if Rails.env.development?
        namespace :dev do
          post "confirmation-token", to: "tokens#confirmation_token"
        end
      end
    end
  end
end
