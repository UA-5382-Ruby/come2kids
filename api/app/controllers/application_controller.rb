class ApplicationController < ActionController::API
  include LocaleHandling
  include ErrorHandling
  include Api::QueryParameters
  include Api::ResponseFormat
  include Authenticatable
end