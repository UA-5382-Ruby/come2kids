module LocaleHandling
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    raw_locale = params[:locale] || extract_locale_from_header
    locale = raw_locale.present? ? raw_locale.to_sym : I18n.default_locale
    locale = I18n.available_locales.include?(locale) ? locale : :uk

    I18n.locale = locale
  end

  def extract_locale_from_header
    header = request.env["HTTP_ACCEPT_LANGUAGE"].to_s
    header.split(",").first&.strip&.scan(/^[a-z]{2}/i)&.first&.downcase
  end
end
