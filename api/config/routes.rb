Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "register", to: "registrations#create"
        post "confirm-email", to: "email_confirmations#confirm"
        post "resend-confirmation", to: "email_confirmations#resend"
      end

      # ---------------------------------------------------------------
      # Development-only helpers — not mounted in production.
      # These endpoints exist solely to support Postman test flows that
      # require data (e.g. confirmation tokens) that would otherwise only
      # be reachable via email.
      # ---------------------------------------------------------------
      if Rails.env.development?
        namespace :dev do
          post "confirmation-token", to: "tokens#confirmation_token"
        end
      end
    end
  end
end
