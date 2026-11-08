Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  get "up" => "rails/health#show", as: :rails_health_check

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