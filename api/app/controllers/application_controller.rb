# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include LocaleHandling
  include ErrorHandling
  include Api::QueryParameters
  include Api::ResponseFormat
end
