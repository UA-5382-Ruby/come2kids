# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Api
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Allow boot without credentials.yml.enc when keys come from ENV
    # (see active_record.encryption below and Compose env).
    config.require_master_key = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.time_zone = 'UTC'
    config.active_record.default_timezone = :utc

    config.i18n.default_locale = :en
    config.i18n.available_locales = [ :uk, :en ]
    config.i18n.fallbacks = [ :uk ]

    # Must be set before Active Record loads so Rails does not read
    # credentials.yml.enc for encryption keys (mismatched master.key breaks boot).
    # Override in production via ENV (see .env.example).
    config.active_record.encryption.primary_key =
      ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY', 'Come2KidsDevPrimaryKeyChangeMe12')
    config.active_record.encryption.deterministic_key =
      ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY', 'Come2KidsDevDeterministicKeyChg')
    config.active_record.encryption.key_derivation_salt =
      ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT', 'Come2KidsDevKeyDerivationSalt12')

    # Sidekiq::Web needs cookies + sessions even in an API-only app.
    config.session_store :cookie_store, key: '_come2kids_session'
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, config.session_options
  end
end
