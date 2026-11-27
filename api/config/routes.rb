# frozen_string_literal: true

require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Sidekiq Web UI — protect with HTTP Basic when credentials are configured.
  if ENV['SIDEKIQ_USERNAME'].present? && ENV['SIDEKIQ_PASSWORD'].present?
    Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(username),
        ::Digest::SHA256.hexdigest(ENV.fetch('SIDEKIQ_USERNAME'))
      ) & ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(ENV.fetch('SIDEKIQ_PASSWORD'))
      )
    end
  end

  mount Sidekiq::Web => '/sidekiq'

  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'auth#login'

      namespace :auth do
        post 'register', to: 'registrations#create'
        post 'confirm-email', to: 'email_confirmations#confirm'
        post 'resend-confirmation', to: 'email_confirmations#resend'
        post 'forgot-password', to: 'forgot_passwords#create'
        post 'reset-password', to: 'reset_passwords#create'
      end

      resources :events, only: [ :index, :show ]

      resources :categories, only: [ :index ]

      # Own profile (US-2.5)
      get 'users/me', to: 'users#show'
      put 'users/me', to: 'users#update'

      # Appeals of blocked users and owners of blocked organizations (US-6.5)
      resources :appeals, only: :create do
        get :current, on: :collection
      end

      # Moderator-only endpoints (EPIC-6)
      namespace :moderation do
        resources :organizations, only: :index do
          member do
            post :approve
            post :reject
            post :block
            post :unblock
          end
        end



        resources :events, only: :index do
          member do
            post :approve
            post :reject
          end
        end

        resources :users, only: [] do
          member do
            post :block
            post :unblock
          end
        end

        resources :appeals, only: %i[index show] do
          member do
            post :accept
            post :reject
          end
        end

        resources :logs, only: :index
      end

      # Organization events (US-5.1)
      resources :organizations, only: [ :create, :update ] do
        resources :reviews, only: %i[index create], controller: 'organization_reviews'
        resources :events, only: %i[index create update destroy], module: :organizations do
          member { post :submit }
          resource :revision, only: :destroy
          resources :images, only: %i[create destroy] do
            collection { patch :order }
          end
          resources :tickets, only: :index, module: :events
          resource :check_in_statistics, only: :show, module: :events
        end
        resources :managers, only: [:index, :create, :destroy],
                  controller: 'organizations/managers',
                  param: :user_id
      end

      resources :events, only: [] do
        resources :orders, only: [ :create ]
        resources :reviews, only: %i[index create], controller: 'event_reviews'
      end

      resources :reviews, only: %i[update destroy], controller: 'event_reviews'
      resources :organization_reviews, only: %i[update destroy]

      resources :orders, only: [ :show ] do
        get :my, on: :collection
      end

      resources :tickets, only: [ :show ] do
        get :my, on: :collection
        member do
          get :qr
          get :pdf
        end
      end

      if Rails.env.development?
        namespace :dev do
          post 'confirmation-token', to: 'tokens#confirmation_token'
        end
      end
    end
  end
end
