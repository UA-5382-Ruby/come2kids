require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# config/application.rb
module Api
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    config.i18n.default_locale = :uk
    config.i18n.available_locales = [ :uk, :en ]
    config.i18n.fallbacks = [ :uk ]

    config.autoload_lib(ignore: %w[assets tasks])
  end
end
