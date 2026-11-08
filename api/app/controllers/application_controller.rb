# frozen_string_literal: true

class ApplicationController < ActionController::API
  include LocaleHandling
  include ErrorHandling
  include Api::QueryParameters
  include Api::ResponseFormat
  include Authenticatable
  include Authorizable # Додано з main (новий модуль авторизації)
end